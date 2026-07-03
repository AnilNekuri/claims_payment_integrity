import json
import os
import signal
from datetime import datetime, timezone
from typing import Any

import psycopg2
from confluent_kafka import Consumer, KafkaError
from dotenv import load_dotenv
from rules import RuleResult, apply_rules


load_dotenv()
RUNNING = True


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def log(level: str, message: str, **fields: object) -> None:
    payload = {
        "timestamp": utc_now(),
        "level": level,
        "jobName": "rules-engine",
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "message": message,
        **fields,
    }
    print(json.dumps(payload, default=str), flush=True)


def stop_handler(signum, frame) -> None:
    global RUNNING
    RUNNING = False
    log("INFO", "Shutdown signal received", signal=signum)


def db_connection():
    return psycopg2.connect(
        host=os.getenv("RDS_HOST", "localhost"),
        port=int(os.getenv("RDS_PORT", "5432")),
        dbname=os.getenv("RDS_DB_NAME", "claims_integrity"),
        user=os.getenv("RDS_USER", "claims_app"),
        password=os.getenv("RDS_PASSWORD", "claims_app"),
    )


def insert_claim_report(cursor, claim: dict[str, Any], result: RuleResult) -> None:
    if result.rule_status == "FAILED":
        return

    cursor.execute(
        """
        INSERT INTO claims_report (
            claim_id, member_id, procedure_code, claim_status, rule_status,
            edit_applied, amount, processed_at
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            result.claim_id,
            claim.get("memberId"),
            claim.get("procedureCode"),
            claim.get("claimStatus"),
            result.rule_status,
            result.edit_applied,
            claim.get("amount"),
            result.processed_at,
        ),
    )


def insert_audit(cursor, claim: dict[str, Any], result: RuleResult, msg) -> None:
    cursor.execute(
        """
        INSERT INTO claim_processing_audit (
            claim_id, kafka_topic, kafka_partition, kafka_offset, rule_status,
            error_type, error_field, message, raw_claim, processed_at
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s)
        """,
        (
            result.claim_id,
            msg.topic(),
            msg.partition(),
            msg.offset(),
            result.rule_status,
            result.error_type,
            result.error_field,
            result.message,
            json.dumps(claim),
            result.processed_at,
        ),
    )


def process_message(conn, msg) -> None:
    claim = json.loads(msg.value().decode("utf-8"))
    result = apply_rules(claim)

    with conn:
        with conn.cursor() as cursor:
            insert_claim_report(cursor, claim, result)
            insert_audit(cursor, claim, result, msg)

    log(
        "ERROR" if result.rule_status == "FAILED" else "INFO",
        result.message,
        claimId=result.claim_id,
        ruleStatus=result.rule_status,
        errorType=result.error_type,
        errorField=result.error_field,
        kafkaTopic=msg.topic(),
        kafkaPartition=msg.partition(),
        kafkaOffset=msg.offset(),
    )


def main() -> None:
    signal.signal(signal.SIGTERM, stop_handler)
    signal.signal(signal.SIGINT, stop_handler)

    topic = os.getenv("KAFKA_TOPIC", "claim-events")
    consumer = Consumer(
        {
            "bootstrap.servers": os.getenv("MSK_BOOTSTRAP_SERVERS", "localhost:9092"),
            "group.id": os.getenv("KAFKA_CONSUMER_GROUP", "claims-rules-engine"),
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )

    conn = db_connection()
    consumer.subscribe([topic])
    log("INFO", "Rules engine started", kafkaTopic=topic)

    try:
        while RUNNING:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() != KafkaError._PARTITION_EOF:
                    log("ERROR", "Kafka consumer error", errorMessage=str(msg.error()))
                continue

            process_message(conn, msg)
            consumer.commit(message=msg)
    finally:
        consumer.close()
        conn.close()
        log("INFO", "Rules engine stopped")


if __name__ == "__main__":
    main()
