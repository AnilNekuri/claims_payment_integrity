import json
import os
from datetime import datetime, timezone

from confluent_kafka import Producer
from dotenv import load_dotenv


load_dotenv()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def log(level: str, message: str, **fields: object) -> None:
    payload = {
        "timestamp": utc_now(),
        "level": level,
        "jobName": "claim-producer",
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "message": message,
        **fields,
    }
    print(json.dumps(payload), flush=True)


def delivery_report(err, msg) -> None:
    if err is not None:
        log("ERROR", "Failed to publish claim event", errorType=type(err).__name__, errorMessage=str(err))
        return

    log(
        "INFO",
        "Published claim event",
        kafkaTopic=msg.topic(),
        kafkaPartition=msg.partition(),
        kafkaOffset=msg.offset(),
    )


def sample_claims() -> list[dict[str, object]]:
    return [
        {
            "claimId": "CLM1001",
            "memberId": "M123",
            "procedureCode": "A0428",
            "claimStatus": "PENDING",
            "triggerProcNbr": "TP100",
            "amount": 450.75,
            "eventTime": utc_now(),
        },
        {
            "claimId": "CLM1002",
            "memberId": "M124",
            "procedureCode": "A0428",
            "claimStatus": "PENDING",
            "amount": 300.00,
            "eventTime": utc_now(),
        },
        {
            "claimId": "CLM1003",
            "memberId": "M125",
            "procedureCode": "J3490",
            "claimStatus": "PENDING",
            "triggerProcNbr": "TP102",
            "amount": 1525.25,
            "eventTime": utc_now(),
        },
    ]


def main() -> None:
    bootstrap_servers = os.getenv("MSK_BOOTSTRAP_SERVERS", "localhost:9092")
    topic = os.getenv("KAFKA_TOPIC", "claim-events")

    producer = Producer({"bootstrap.servers": bootstrap_servers})
    log("INFO", "Starting claim producer", kafkaTopic=topic)

    for claim in sample_claims():
        producer.produce(
            topic,
            key=str(claim["claimId"]),
            value=json.dumps(claim),
            callback=delivery_report,
        )
        producer.poll(0)

    producer.flush()
    log("INFO", "Claim producer finished", producedClaims=len(sample_claims()))


if __name__ == "__main__":
    main()
