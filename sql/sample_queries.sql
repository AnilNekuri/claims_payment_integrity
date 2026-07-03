SELECT rule_status, COUNT(*) AS claim_count
FROM claims_report
GROUP BY rule_status
ORDER BY claim_count DESC;

SELECT error_field, COUNT(*) AS error_count
FROM claim_processing_audit
WHERE rule_status = 'FAILED'
GROUP BY error_field
ORDER BY error_count DESC;

SELECT a.claim_id, a.rule_status AS audit_status, r.rule_status AS report_status
FROM claim_processing_audit a
LEFT JOIN claims_report r ON r.claim_id = a.claim_id
WHERE r.claim_id IS NULL OR a.rule_status <> r.rule_status;
