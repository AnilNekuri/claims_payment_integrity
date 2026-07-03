from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


REQUIRED_FIELDS = ("claimId", "procedureCode", "claimStatus", "triggerProcNbr")
VALID_STATUSES = {"PENDING", "APPROVED", "DENIED"}
PREPAY_EDIT_PROCEDURE_CODES = {"A0428", "J3490"}


@dataclass
class RuleResult:
    claim_id: str | None
    rule_status: str
    edit_applied: bool
    error_type: str | None
    error_field: str | None
    message: str
    processed_at: str


def apply_rules(claim: dict[str, Any]) -> RuleResult:
    processed_at = datetime.now(timezone.utc).isoformat()

    for field in REQUIRED_FIELDS:
        if field not in claim or claim[field] in (None, ""):
            return RuleResult(
                claim_id=claim.get("claimId"),
                rule_status="FAILED",
                edit_applied=False,
                error_type="KeyError",
                error_field=field,
                message=f"Missing required field {field}",
                processed_at=processed_at,
            )

    if claim["claimStatus"] not in VALID_STATUSES:
        return RuleResult(
            claim_id=claim.get("claimId"),
            rule_status="FAILED",
            edit_applied=False,
            error_type="InvalidStatus",
            error_field="claimStatus",
            message=f"Invalid claim status {claim['claimStatus']}",
            processed_at=processed_at,
        )

    amount = float(claim.get("amount") or 0)
    edit_applied = amount > 1000 or claim["procedureCode"] in PREPAY_EDIT_PROCEDURE_CODES

    return RuleResult(
        claim_id=claim.get("claimId"),
        rule_status="REVIEW" if edit_applied else "PASSED",
        edit_applied=edit_applied,
        error_type=None,
        error_field=None,
        message="Claim processed successfully",
        processed_at=processed_at,
    )
