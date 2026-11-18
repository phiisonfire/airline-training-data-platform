# Data quality

Contract/identity/relational/temporal/rule validators, issue semantics và reconciliation.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Phân biệt missing/null/empty/wrong type/malformed; preserve intentionally bad raw.
- Identity conflict, graph error và parse error không biến thành business fail hoặc qualified.
- Issues có safe source refs, parser/contract version, affected scope và remediation/replay history trong tenant boundary.
- Gate policy theo affected product và severity; orchestration consume kết quả validator.
- Test raw fixtures và independent assertions; generator DQ labels chỉ là oracle riêng.
