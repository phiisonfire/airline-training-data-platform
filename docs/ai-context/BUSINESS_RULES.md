# BUSINESS_RULES — Multi-airline Training Data Platform

Ngày baseline: 2026-11-17. Nguồn ACCEPTED là mô tả/yêu cầu của người dùng khi
chuẩn bị repo platform. Chưa có platform implementation được kiểm chứng trong
gói này. Source reference dưới đây là mock contract, không là aviation policy thật.

## A. Business requirements — ACCEPTED

### BR-01. Nhà cung cấp và khách hàng

Platform thuộc công ty cung cấp giải pháp training cho các hãng hàng không.
Mỗi hãng là một tenant có SQL Server source databases, graph database và custom
transformation/mapping rules riêng. Organization/location là đơn vị nội bộ hãng.
Nguồn ETR/LMS/Flight/QMS được xử lý trong tenant context tương ứng.

### BR-02. Tenant data boundaries

Thiết kế phải hỗ trợ khách yêu cầu data được lưu riêng với hãng khác. Không mặc
định gom employee/evidence/rule/business facts vào tables chung. Isolation tier
cần xác nhận; schema/folder riêng hoặc RLS chưa tự chứng minh storage separation.
Source/canonical IDs có thể trùng giữa hãng; không tự hợp nhất hồ sơ xuyên hãng.

### BR-03. Daily reporting và trách nhiệm BI

Hai reports chính là **pilot learning status** và **pilot qualification status**
trên Power BI. DE cung cấp serving layer đầy đủ, công bố **1 lần/ngày**. BI dev
xây reports/semantic model/DAX/visuals. Handoff gồm grain, keys/relationships,
typed fields, definitions, access/freshness contract và dữ liệu/queries đối soát.
Cutoff, giờ deadline, timezone và late-source policy vẫn OPEN; cadence daily
không đồng nghĩa đã chốt end-to-end Power BI display SLA.

### BR-04. Qualification backfeed cho client application

Platform tính và ghi pilot qualification status tới targeted SQL Server để
application client sử dụng. Mục tiêu latency **càng nhỏ càng tốt**; numeric
percentile/threshold chưa được xác nhận. Không lấy daily reporting schedule hoặc
ngưỡng 15 phút làm SLA mặc định. Không có yêu cầu backfeed learning status/raw
training/Flight/warehouse vào application trong baseline hiện tại.

### BR-05. Shared semantics, hai lịch công bố

Reporting và backfeed dùng chung qualification definitions, identity và policy
versioning. Backfeed không chờ daily BI batch. Report là snapshot tại cutoff/as-of;
app là current applied state. Đối soát tại cùng input/rules/as-of; không ép hai
thời điểm khác nhau có cùng status. Rerun historical report không ghi đè app current.

### BR-06. Employmentdate và custom seniority

TMDS user có field `employmentdate`; downstream tính số năm employed rồi map
seniority theo quy ước riêng từng hãng. Không dùng created_at thay ngày tuyển
dụng. Seniority labels/bands có thể khác nhau dù years employed giống nhau.
Chưa có yêu cầu dùng seniority để thay qualification rules. Rehire, leave gaps
hoặc kinh nghiệm ở hãng khác chưa được mô tả; không tự suy ra từ một hire date.

### BR-07. Phạm vi bài thực hành

Mục tiêu là upskill xây platform gồm ingestion/ETL/ELT, modeling, DQ, monitoring,
governance, CI/CD/IaC và recovery trên các tech stack. Cập nhật 2026-11-17: người dùng chọn một data platform trên AWS trong repo này;
không tiếp tục multi-stack implementations. Terraform và AWS CodePipeline được chọn cho DevOps slice ngày 2026-11-18;
service implementation chi tiết xem ADR 0002, cloud environment chưa chốt. Report authoring,
client application development và vận hành production không được tự mở rộng
thành phạm vi triển khai nếu chưa được giao.

### BR-08. DevOps-first milestone — ACCEPTED 2026-11-18

Người dùng ưu tiên CI/CD với AWS CodePipeline, IaC Terraform có extension seam
cho AWS CDK, và docs học/phỏng vấn. Business slice hiện tại thu hẹp thành extract
một SQL Server test table, mapping/filter và ghi S3. Full qualification/seniority,
hai BI products và app SQL backfeed DEFERRED trong milestone, không xóa full scope.
Fixture devops.pilot_source là downstream synthetic contract, không suy ra source
TMDS DDL. Local/mock tests không chứng minh deployed AWS/IAM/SQL behavior.

## B. Source contract reference — VERIFY AGAINST PINNED UPSTREAM

Baseline khi bàn giao: upstream mockgen 0.5.0, contract synthetic-v5. Phải pin và
đối chiếu source/tests/contracts của version thực tế; không coi bảng dưới là DDL
production hoặc bằng chứng repo platform đã triển khai logic đó.

| Ref | Hợp đồng/hành vi mock cần bảo toàn |
|---|---|
| SRC-01 | TMDS chuẩn organization/location; registry nối canonical pilot với source IDs riêng TMDS/ETR/LMS/Flight trong một hãng. Flight active mapping phải duy nhất, không fallback |
| SRC-02 | Required qualifications từ active user/role/user-role/role-qualification; multi-role lấy hợp và giữ provenance. Assignment khác achievement; missing assignment không tự cấp mọi qualification |
| SRC-03 | Actual Flight độc lập ETR; simulator duration không cộng vào actual-flight seconds. Parse datetime/duration theo explicit contract/metadata, ambiguous không tự đoán |
| SRC-04 | Latest Flight revision thắng; duplicate delivery không tăng totals; cùng ID/revision khác body quarantine; tombstone loại khỏi active evidence, raw history giữ lại |
| SRC-05 | ETR assessment → section rows → JSON items. Mean grades integer HALF_UP; mọi section phải pass. Empty string comment khác null/wrong type/missing; missing evidence khác malformed evidence |
| SRC-06 | LMS/ETR evidence phải đúng user/course/exam/template target. Current reference chọn ETR/exam attempt cuối theo snapshot order; timestamp-based latest cần quyết định/version riêng |
| SRC-07 | Qualification statuses: QUALIFIED, NOT_QUALIFIED, PENDING_EVIDENCE, PENDING_REVIEW, EXPIRED, REVOKED, EVALUATION_ERROR. Technical errors không đổi thành business failure/success; không tự cấp certification |
| SRC-08 | QMS graph có requirements/dependencies, AND/OR, effective dates và rule versions; invalid/cyclic/dangling/unsupported graph là technical error |
| SRC-09 | employmentdate bắt buộc cho mọi TMDS user gồm manager; ISO YYYY-MM-DD, SQL Server DATE. Field không chứa years_employed/seniority; syntactically valid future date cần downstream xử lý theo as-of |
| SRC-10 | Snapshot khác INSERT/UPDATE/DELETE. Source deactivation dùng is_active, Flight delete dùng mock tombstone. Incremental replay cần manifest/effective generation config/checkpoint, không chỉ seed |

Mockgen raw/source entities, registry, graph và delivery metadata là test inputs.
Generator-derived Flight normalization/evaluations/DQ/audit là validation oracle
riêng; không dùng chúng để tạo platform results. Mockgen source SQL publisher
không phải client qualification status backfeed sink.

## C. Engineering guardrails — DEFAULTS, chưa phải runtime guarantees

- Giữ raw; preserve missing/null/empty/type boundaries và intentionally bad fixtures.
- Data products có explicit grain/key/owner/lineage/contract version; tenant
  context trusted, source/target mismatch bị chặn trước khi write.
- Qualification decision lưu rule snapshot/version, input/evidence refs và as-of;
  tách technical uncertainty khỏi business outcome. Quy tắc AND/OR không bị đổi
  thành một global all-pass shortcut.
- Daily report giữ expected targets kể cả thiếu evidence; child attempt/section/
  item tables có grain riêng để tránh fan-out và mất pending pilots.
- Backfeed sink idempotent, per-key ordering, ack-after-commit, durable retries,
  reconciliation; replay cũ không overwrite status mới/revoked state.
- Stale QUALIFIED sau error/inactive/removed assignment cần app lifecycle/technical/
  freshness contract; không tự hard-delete, retain-as-current hoặc ép enum.
- Tenant isolation bao phủ data/state/temp/logs/quarantine/BI extracts/cache/backups;
  permissions/cross-tenant negative tests là điều kiện nghiệm thu deployment tier.
- Không tuyên bố exactly-once, RLS enforcement, concurrency guarantees hoặc SLA
  attainment khi chưa có tests/measurement cho phạm vi cụ thể.

## D. Seniority policy mẫu — PROPOSED, KHÔNG PHẢI HR POLICY ĐÃ DUYỆT

Baseline đề xuất: completed calendar-anniversary years tại as-of date theo
business timezone hãng; hire 29/02 dùng anniversary 28/02 ở năm không nhuận.
Không dùng days/365 hoặc calendar-year subtraction đơn lẻ.

| Hãng giả lập | Junior | Experienced | Senior |
|---|---|---|---|
| AIRLINE-A | [0,3) | [3,10) | [10,+∞) |
| AIRLINE-B | [0,5) | [5,15) | [15,+∞) |

Policy cần tenant, ID/version, effective window [from,until), timezone,
anniversary convention và bands [min,max). Chỉ một effective policy và một
matching band; missing/overlap/gap là configuration error, không fallback.
Invalid/future employmentdate trả missing/error state thay vì Junior mặc định.
Đánh giá lại khi anniversary, source correction hoặc policy đổi; historical
publication giữ nguyên. Ví dụ hire 2022-11-17, as-of 2026-11-17 → 4 năm,
A-Experienced và B-Junior. Đây là fixture để chốt policy và viết tests.

## E. Open decisions — không tự nâng thành business rules

- AWS services/account/Region/environment/budget/scale, source pin/location và ingestion capabilities.
- Daily cutoff/deadline/timezone/calendar, late-source/degraded reporting policy.
- Numeric backfeed SLO và điểm bắt đầu source availability measurement.
- Target SQL physical schema, client pilot mapping, enums, ownership/conflicts,
  transactional grouping/read visibility và error/inactive/removed/stale semantics.
- Latest attempt selection, learning-status rollup mapping và grading overrides.
- Seniority bands/calendar conventions, effective-date approval và rehire semantics.
- Isolation tier, scope enforcement/historical access, retention, RPO/RTO.

## F. Evidence và cập nhật

Khi có quyết định mới, ghi người dùng/yêu cầu/ADR làm evidence và update status.
Khi source/code thay đổi, chỉ ghi IMPLEMENTED kèm paths/tests đã chạy ở repo này.
Không nhập test counts hoặc deployment history của upstream vào platform status.
