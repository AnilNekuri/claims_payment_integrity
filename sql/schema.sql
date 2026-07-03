CREATE TABLE IF NOT EXISTS claims_report (
    id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50) NOT NULL,
    member_id VARCHAR(50),
    procedure_code VARCHAR(50),
    claim_status VARCHAR(50),
    rule_status VARCHAR(50),
    edit_applied BOOLEAN DEFAULT FALSE,
    amount NUMERIC(12,2),
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_claims_report_claim_id
    ON claims_report (claim_id);

CREATE TABLE IF NOT EXISTS claim_processing_audit (
    id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50),
    kafka_topic VARCHAR(100),
    kafka_partition INT,
    kafka_offset BIGINT,
    rule_status VARCHAR(50),
    error_type VARCHAR(100),
    error_field VARCHAR(100),
    message TEXT,
    raw_claim JSONB,
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_claim_processing_audit_claim_id
    ON claim_processing_audit (claim_id);

CREATE TABLE IF NOT EXISTS job_status (
    id SERIAL PRIMARY KEY,
    job_name VARCHAR(100),
    job_type VARCHAR(50),
    status VARCHAR(50),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    error_count INT DEFAULT 0,
    warning_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dmr_requests (
    id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50),
    issue_type VARCHAR(100),
    source_system VARCHAR(50),
    description TEXT,
    status VARCHAR(30) DEFAULT 'OPEN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);
