# Business Requirements — Pilot Training & Qualification Data Platform

Phiên bản: 1.2 · Ngày: 2026-11-17 · Ngôn ngữ triển khai: tùy tech stack.

Đối tượng sử dụng: Data Engineer và AI agent cùng xây dựng data platform để thực hành.
Nguồn dữ liệu thực hành: repository `pilot_training_platform_mock_data_generator`.

## 1. Mục đích và cách sử dụng tài liệu

Người học đóng vai Data Engineer của **công ty cung cấp giải pháp training cho
các hãng hàng không**. Mỗi hãng khách hàng là một tenant, có SQL Server source
databases, graph database và custom transformation/mapping rules riêng. Trong
phạm vi từng hãng, platform hợp nhất nhân sự, đào tạo và chuyến bay để trả lời:
**phi công nào cần qualification nào, hiện đáp ứng đến đâu, thiếu bằng chứng gì,
thuộc seniority nào theo quy ước hãng và kết luận có đáng tin cậy không?**

Platform có **hai luồng nghiệp vụ chính**:

| Luồng | Consumer / đầu ra | SLA và phạm vi đã xác nhận |
|---|---|---|
| Reporting | Serving layer cho **pilot learning status report** và **pilot qualification status report** trên Power BI | Refresh/công bố dữ liệu 1 lần/ngày; BI dev xây report, Data Engineer bàn giao data serving contracts |
| Qualification backfeed | Pilot qualification status ghi vào **SQL Server đích** để application của client sử dụng | Độ trễ càng nhỏ càng tốt; chưa có ngưỡng latency bằng số được xác nhận |

Hai luồng dùng chung định nghĩa qualification, identity và policy versions, nhưng
có checkpoint, publication/delivery state và lịch vận hành riêng. Backfeed không
phải đợi daily reporting batch hoặc Power BI refresh. Chi tiết ở mục 18.

Mục tiêu thực hành là hoàn thành vòng đời của một data product: ingestion,
ETL/ELT, mô hình dữ liệu, data quality, phục vụ phân tích, monitoring, governance,
CI/CD, Infrastructure as Code (IaC), vận hành và recovery. Có thể triển khai lại
cùng bài toán trên AWS, Azure, Databricks, Snowflake hoặc môi trường local.

Tài liệu quy định kết quả nghiệp vụ và bằng chứng nghiệm thu; agent lựa chọn
kiến trúc, công cụ và dịch vụ phù hợp với môi trường được giao. Không bắt buộc
triển khai tất cả tech stack trong một lần thực hành.

### 1.1. Trạng thái và thứ tự ưu tiên

- **ACCEPTED — mục tiêu:** dùng mock data có business context để thực hành xây
  dựng data platform hoàn chỉnh trên nhiều tech stack, theo yêu cầu người dùng.
- **ACCEPTED — bối cảnh cập nhật:** nhà cung cấp training phục vụ nhiều hãng;
  mỗi hãng có sources và mapping riêng. Bổ sung `employmentdate` vào TMDS user;
  downstream tính seniority theo số năm employed và mapping từng hãng. Thiết kế
  phải hỗ trợ yêu cầu lưu trữ dữ liệu tách biệt giữa các hãng.
- **ACCEPTED — hai luồng:** daily reporting phục vụ hai report Power BI qua
  serving layer; qualification backfeed vào SQL Server đích với mục tiêu latency
  thấp nhất khả thi. Report authoring thuộc BI dev. Mọi ngưỡng freshness chung
  đề xuất trước đây không thay thế yêu cầu hai luồng này.
- **CURRENT — hiện trạng nguồn:** hành vi đã đối chiếu source code và contracts
  trong repo tại thời điểm soạn. Không có nghĩa đã kiểm chứng hệ thống cloud.
- **PROPOSED — yêu cầu đích:** data products, KPI, SLO, governance và kịch bản
  platform trong tài liệu là bản đề xuất cho bài thực hành, chưa phải policy
  production hay chức năng đã triển khai. Agent cần ghi nhận baseline lựa chọn
  trước khi viết code; điểm còn mở được liệt kê ở mục 15.
- **EXTENSION — mở rộng:** cần fixture, test harness hoặc thay đổi generator
  riêng; không được tuyên bố repo hiện đã hỗ trợ.

Source code/tests quyết định generator đang làm gì; [contracts hiện tại](../docs/contracts.md)
quy định contract mock. Tài liệu này quy định platform cần cung cấp gì. Nếu có
mâu thuẫn, ghi rõ gap và quyết định xử lý, không âm thầm thay đổi nghiệp vụ nguồn.

### 1.2. Repository deployment baseline — ACCEPTED, 2026-11-17

Người dùng chọn xây một data platform bằng AWS services trong repo này, thay
cho nhiều implementations theo cloud/framework. Những nội dung multi-stack ở
trên là bối cảnh mục tiêu học tập trước đây; không còn là yêu cầu repository.
Business semantics, multi-tenant isolation và hai output paths giữ nguyên.
AWS service list, account/Region, budget, runtime và IaC tool chưa được chọn.
Xem [ADR 0001](../docs/adr/0001-single-aws-platform.md) và
[AWS blueprint](../docs/architecture/aws-platform.md). Đây chưa phải deployment.

### 1.3. Milestone DevOps — ACCEPTED, 2026-11-18

Người dùng ưu tiên Terraform (có đường mở rộng AWS CDK) và AWS CodePipeline cho
CI/CD, đồng thời cần tài liệu học/phỏng vấn. Business slice hiện tại được thu hẹp
thành extract một SQL Server test table → mapping/filter → S3. Qualification,
seniority, hai daily report products và SQL qualification backfeed DEFERRED trong
milestone này; không xóa full business scope/acceptance phía dưới hoặc báo platform
hoàn thành từ slice nhỏ. Xem [ADR 0002](../docs/adr/0002-devops-terraform-codepipeline.md)
và [learning path](../docs/devops/README.md). AWS deployment vẫn cần account/Region/
budget/isolation/network/source authorization và reviewed plan riêng.

## 2. Bối cảnh kinh doanh

Nhà cung cấp vận hành giải pháp cho nhiều hãng độc lập. Trong **mỗi hãng**, phi
công thuộc nhiều organization và location. `organization_id`/`location_id` không
thay cho `tenant_id`. Source user/flight/qualification IDs có thể trùng giữa hai
hãng, và cùng số năm làm việc có thể cho seniority khác nhau do custom mapping.
Mỗi người có một hoặc nhiều job role; từng role yêu cầu một tập qualification. Qualification phụ
thuộc vào các bằng chứng như hoàn thành khóa học, thi đạt, assessment đạt hoặc
đủ thời lượng bay thực tế trong một cửa sổ thời gian.

Dữ liệu nằm ở nhiều hệ thống, có ID riêng và có thể đến chậm, bị sửa, bị thu hồi
hoặc sai định dạng. Báo cáo tổng hợp thủ công dễ đếm trùng chuyến bay, nối nhầm
người, dùng sai phiên bản quy tắc hoặc coi lỗi kỹ thuật là không đạt nghiệp vụ.

Platform cần giúp bộ phận đào tạo phát hiện khoảng thiếu, quản lý xem tình trạng
trong phạm vi được giao và kiểm toán truy ngược được mọi kết luận đến dữ liệu gốc.
Kết quả phục vụ đào tạo/phân tích giả lập; không phải quyết định cấp phép bay hay
tự động cấp certification.

### 2.1. Stakeholders và câu hỏi cần trả lời

| Stakeholder | Quyết định cần hỗ trợ | Câu hỏi tiêu biểu |
|---|---|---|
| Training Manager | Ưu tiên đào tạo bổ sung | Ai thiếu assessment, khóa học, exam hoặc thời lượng bay? |
| Organization/Location Manager | Theo dõi đơn vị được giao | Tỷ lệ đáp ứng qualification của đơn vị là bao nhiêu? |
| Qualification/Compliance Analyst | Giải thích kết quả | Kết quả dựa trên rule version và evidence nào? |
| Data Steward | Điều phối sửa dữ liệu nguồn | Lỗi thuộc domain nào, ai sở hữu, ảnh hưởng những kết quả nào? |
| Data Engineer / Operator | Vận hành và phục hồi | Nguồn nào trễ, batch nào lỗi, replay có làm đổi số liệu không? |
| Auditor | Tái dựng báo cáo | Tại lần công bố X, platform đã biết gì và dùng quy tắc nào? |
| Platform Owner | Quản lý chi phí và thay đổi | Một lần load/rebuild tốn bao nhiêu, có thể tái triển khai không? |
| Airline Data Owner | Kiểm soát dữ liệu và quy ước riêng | Dữ liệu có được cô lập, seniority có dùng đúng mapping của hãng không? |
| Provider Operations | Vận hành nhiều tenant | Onboard/upgrade/recover một hãng có ảnh hưởng hãng khác không? |
| BI Developer | Xây Power BI learning/qualification reports | Serving layer có đủ grain, dimensions, statuses, lịch sử và freshness cho hai report không? |
| Client Application Owner | Dùng qualification status trong application | SQL Server đích nhận đúng current status, đúng pilot, đúng version và đủ nhanh chưa? |

## 3. Phạm vi và ranh giới hệ thống

### 3.1. Các nguồn hiện có — CURRENT

Contract hiện tại là `synthetic-v5`; physical schema là schema giả lập, không
đại diện cho schema production của hãng hàng không hay sản phẩm cùng tên.

Inventory dưới đây là **một source universe của một hãng**. Mockgen hiện chạy
một config/Store/run lineage mỗi lần; multi-tenant control plane và downstream
isolation là yêu cầu platform, chưa được generator thực thi. Hai config mẫu
`configs/airline-a.example.yaml`, `configs/airline-b.example.yaml` tách output
local và cố ý cho phép IDs giống nhau để kiểm thử.

| Domain | Dữ liệu và trách nhiệm | Grain/key chính cần bảo toàn |
|---|---|---|
| TMDS | Users có `employmentdate`, organizations, locations, manager scopes, job roles và mappings | User/role/catalog theo `id`; user-role và role-qualification có natural key riêng; employmentdate là ISO date / SQL DATE |
| LMS | Courses, classes, lessons, enrollments, progress, attendance, exam results | Enrollment riêng; exam result theo record/attempt, không gộp mọi attempt của user |
| ETR | Users, assessment templates, assessments, assessment elements | Assessment là một attempt của user/template; `assessment_elements` là section, JSON chứa items |
| Flight API | Raw deliveries của chuyến bay thực tế | Logical flight theo stable `flight_record_id`, có revisions và tombstone trong mock metadata |
| QMS | Qualification, requirement graph, rule versions và evidence mappings | Node theo logical ID; dependency graph và snapshot/version của rule |
| Registry | Liên kết canonical pilot ID với TMDS/ETR/LMS/Flight IDs | Mapping danh tính xuyên nguồn; source IDs không mặc nhiên bằng nhau |

Registry là contract hỗ trợ bài thực hành; nếu chưa đưa vào SQL/API, ingestion
phải nhận nó qua artifact hoặc giao diện riêng đã khai báo. Không suy diễn ID từ
prefix số hay nối trực tiếp ID của hai nguồn khác nhau.

### 3.2. Phần generator cung cấp và phần người học phải xây

**Generator cung cấp:** baseline, các thay đổi source có kiểm soát, DQ scenarios,
raw artifacts, graph snapshot, manifest/audit, reference normalization và
qualification evaluations để đối chiếu. Có khả năng publish SQL/graph và phục
vụ Flight HTTP API bằng lệnh riêng; chưa xác nhận những service đó đang chạy.

**Platform phải xây:** ingestion độc lập, lưu raw, transformation, business data
products, kiểm soát DQ, serving, phân quyền thật trong stack được chọn,
observability, deployment, CI/CD/IaC và quy trình vận hành.

Không dùng `flights.jsonl`, `evaluations.jsonl`, `dq_issues.jsonl` hoặc scenario
audit làm dữ liệu đầu vào để tạo kết quả nghiệp vụ đích. Giữ chúng trong vùng
validation riêng làm reference oracle. Metadata `_mock` dùng làm input khi đó là
contract giải mã datetime/duration/revision; không dùng nhãn scenario hoặc expected
outcome để quyết định pipeline phải trả gì.

### 3.3. Hai chế độ thực hành

- **Artifact mode:** ingest source entities, registry, `flights_raw.jsonl` và QMS
  graph từ snapshot/exports. Phù hợp phát triển local, kiểm chứng nghiệp vụ và CI.
  `change_events.jsonl` có thể dùng như nguồn CDC mô phỏng nếu khai báo rõ.
- **Integration mode:** ingest TMDS/LMS/ETR từ SQL source, Flight từ HTTP API,
  QMS từ graph source; registry vẫn phải có giao diện nhận riêng. Agent phải
  thực hành extraction/checkpoint thực tế thay vì đọc kết quả derived của repo.

Change events của generator không phải SQL Server transaction log hay dịch vụ
CDC managed. Flight API mock là API phân trang của một snapshot; không được giả
định có webhook, streaming, authentication enforcement, rate limiting hoặc
incremental cursor theo thời gian nếu chưa xây thêm.

### 3.4. Ngoài phạm vi mặc định

Crew scheduling, tối ưu lịch bay, payroll, aircraft maintenance, booking/revenue,
machine learning, giao diện nghiệp vụ đầy đủ và tích hợp hệ thống production.
Power BI report authoring, layout/DAX/semantic model triển khai bởi BI dev;
Data Engineer bàn giao serving data, relationships, business measures, security
contract và queries/expected results để BI dev xây hai report. Consumer application
cũng ngoài phạm vi xây dựng; integration SQL Server backfeed nằm trong phạm vi
platform. Streaming liên tục là lựa chọn triển khai tùy latency/capabilities,
chưa bị bắt buộc; multi-region và concurrent writers là EXTENSION.

## 4. Quy tắc nghiệp vụ cần bảo toàn — CURRENT

### BR-01. Danh tính, tổ chức và phạm vi quản lý

- TMDS là nguồn chuẩn về organization/location; registry nối danh tính xuyên nguồn.
- Mapping Flight active phải duy nhất. Thiếu, xung đột hoặc nonunique mapping
  phải được phát hiện; không fallback sang người khác hoặc mọi phi công.
- Không đồng nhất missing, `None`, chuỗi rỗng, sai kiểu và malformed JSON.
- Manager scopes trong generator là fixtures. Enforcement thuộc platform; không
  cấp quyền mặc định khi scope thiếu hoặc bị thu hồi.

### BR-02. Required qualification khác với achieved qualification

- Required qualifications lấy từ active user → active user-role → active job
  role → active role-qualification mapping. Multi-role lấy hợp, loại trùng và
  giữ provenance role nguồn. `user_type` không thay thế job role.
- Không có assignment hợp lệ thì không tự gán mọi qualification. Mapping hỏng
  phải báo lỗi thay vì diễn giải thành không có yêu cầu.
- Qualification expired/revoked vẫn có thể nằm trong tập bắt buộc; assignment
  và trạng thái đáp ứng là hai khái niệm riêng.
- Evidence LMS/ETR phải đúng user, course/exam/template mà rule yêu cầu. Không
  thay thế evidence thiếu bằng một khóa học hay assessment không liên quan.

### BR-03. Flight evidence và thời gian

- Actual Flight độc lập ETR; không yêu cầu mỗi flight có assessment parent.
  Thời lượng simulator không cộng vào actual-flight totals.
- Raw duration và canonical integer seconds lưu riêng. Chỉ parse giá trị mơ hồ
  khi có contract về unit, `colon_format`, locale hoặc cú pháp explicit.
- Datetime phải giữ raw, timezone/offset và canonical UTC. Thiếu contract để
  giải quyết giá trị mơ hồ phải báo lỗi; không đoán theo máy chạy pipeline.
- Latest revision của flight thắng. Duplicate delivery cùng ID/revision/body
  không tăng tổng; cùng ID/revision khác body phải quarantine.
- Tombstone loại logical flight khỏi evidence hiện tại; raw history vẫn giữ.
- Fixture mặc định `QUAL-1` yêu cầu ít nhất 1.800 giây trong 90 ngày, tính theo
  departure event time, gồm hai biên `[as_of - 90 ngày, as_of]`. Threshold/window
  phải đọc từ rule snapshot thay vì hard-code. Đây là mock policy.

### BR-04. ETR và LMS

- ETR assessment có nhiều section rows; mỗi section có các items trong JSON.
  Không coi `assessment_elements` là grain một item.
- Item score/grade là integer 0–100. Section grade là mean item scores; overall
  grade là mean section grades; làm tròn HALF_UP đến integer.
- Mọi section phải đạt passing grade để assessment pass; overall cao không che
  một section failed. Mặc định 3 sections, 4 items/section, threshold 75.
- Comment rỗng là string hợp lệ; missing/null/non-string là lỗi contract.
  Thiếu section hoặc item list rỗng có thể là pending evidence; malformed JSON,
  sai kiểu hoặc grade/status mâu thuẫn là lỗi kỹ thuật.
- LMS requirement hiện xét course/exam đúng target, enrollment active completed
  và exam result passed. Attendance/progress là dữ liệu phân tích riêng; không
  tự thêm chúng vào điều kiện pass nếu rule chưa quy định.
- Evaluator hiện chọn ETR/exam attempt cuối theo thứ tự snapshot, chưa chọn theo
  event timestamp. Platform muốn thay chính sách phải version hóa và kiểm thử
  riêng; không tuyên bố đã đạt parity khi vẫn có khác biệt này.

### BR-05. Kết luận qualification phải giải thích được

Các trạng thái hiện có: `QUALIFIED`, `NOT_QUALIFIED`, `PENDING_EVIDENCE`,
`PENDING_REVIEW`, `EXPIRED`, `REVOKED`, `EVALUATION_ERROR`.

- Business fail hợp lệ là `NOT_QUALIFIED`; lỗi parse, identity hoặc graph không
  được chuyển thành business fail hay tự bỏ qua để kết luận `QUALIFIED`.
- Graph có AND/OR, dependencies, effective dates và rule versions. Graph cycle,
  dangling reference hay unsupported requirement cần báo lỗi kỹ thuật.
- OR có thể đạt khi một nhánh đạt; không áp dụng quy tắc “mọi nhánh đều đạt” cho
  OR. Khi chưa có nhánh đạt, evaluator ưu tiên trạng thái lỗi/không đạt theo
  policy hiện hành; agent phải dùng `qms.py` và test cases để chốt parity.
- Kết luận cần có pilot, qualification, rule version, evaluation time, evidence
  references, requirement đạt/thiếu/không đạt và technical errors nếu có.
- Sinh đủ evidence không đồng nghĩa cấp certification. Lịch sử run cũ bất biến.

### BR-06. Tái lập và lịch sử nguồn

`SNAPSHOT` khác `INSERT`/`UPDATE`/`DELETE`; replay phải theo parent lineage.
Source deactivation dùng `is_active`; Flight delete dùng `_mock.deleted`.
Giữ `created_at` khi update, bảo toàn `updated_at` từ source.

Seed/config ổn định giúp tái lập logical records, nhưng incremental run mới lấy
UTC execution time một lần và lưu effective `generation_config` trong manifest.
Tái dựng incremental cần manifest/clock đã lưu, không chỉ seed. Không dùng đồng
hồ hiện tại để đánh giá lại một historical run rồi kỳ vọng kết quả không đổi.

## 5. Data products cần bàn giao — PROPOSED

Đây là logical contracts của platform đích; không phải tên bảng đã có trong
generator. Agent tự chọn physical schema, partitioning và mô hình lưu trữ.

| ID | Data product và grain | Nội dung tối thiểu | Người dùng |
|---|---|---|---|
| DP-01 | Pilot profile: một canonical pilot tại một trạng thái công bố | Source IDs, active flag, organization/location, roles, mapping health; lịch sử thay đổi | Training, managers |
| DP-02 | Required qualifications: một pilot × qualification tại một trạng thái công bố | Role provenance, assignment validity, rule reference; tách khỏi status | Training, compliance |
| DP-03 | Flight evidence: một logical flight ở current state; có revision history riêng | Raw reference, revision, canonical pilot, departure UTC, integer seconds, eligibility, deletion và DQ reasons | Analysts, compliance |
| DP-04 | Training evidence: assessment attempt/section/item và LMS enrollment/exam attempt có grain riêng | Target selectors, grades/status, completion, source lineage; không nhân bản khi join | Training |
| DP-05 | Qualification status: một pilot × required qualification × evaluation/publication | Status, rule version, evaluation as-of, requirement outcomes, evidence refs, errors | Training, managers |
| DP-06 | Training gaps và unit summary: detail theo pilot/qualification/requirement; summary theo organization/location/publication | Gap reason, trạng thái, KPI có denominator rõ và DQ coverage | Managers |
| DP-07 | Data quality & operations: issue occurrence và pipeline/source batch | Rule/severity, affected refs, first/last seen, owner, xử lý; ingestion/publication freshness và run outcomes | Steward, operators |

Mọi product phải có data contract: grain, key, field types/nullability, owner,
classification, upstream lineage, refresh expectation, version và consumer query.
Current views không nhân đôi pilot/qualification do multi-role hoặc nhiều items.
Grain/key của mọi product đều nằm trong một tenant; các grain ở bảng trên ngầm
có `tenant_id`. Registry canonical identity chỉ có ý nghĩa trong một hãng; không
tự hợp nhất hồ sơ của hai hãng vì có cùng email hoặc source ID.

**DP-08 — Employee seniority:** một tenant × TMDS user × as-of date × publication.
Gồm raw employmentdate reference, canonical date, `years_employed`, seniority
code/label, mapping policy/version, business timezone, calculation status và
error reason. Hỗ trợ managers và pilots; không mặc nhiên coi manager là pilot.

**DP-09 — Daily reporting serving:** hai report-facing contracts: learning status
ở grain pilot × learning target × report date/publication; qualification status
ở grain pilot × required qualification × report date/publication. Có dimensions,
detail evidence, seniority, reason/coverage/freshness và relationships cho BI dev.
Không ép course, exam attempt, assessment section vào cùng một fact grain.

**DP-10 — Operational qualification backfeed:** một tenant × client pilot identity
× qualification ở current state trong SQL Server đích, có evaluation/version,
as-of, timestamps, delivery provenance và technical/freshness state theo client
contract. Đây là application read model, khác daily reporting snapshot.

Mỗi publication có ID liên kết với source run(s), parent/checkpoint, source
contract, transformation/parser version và rule snapshot. Daily report công bố
nhất quán giữa các reporting products bằng version/pointer hoặc cơ chế tương
đương, tránh đọc nửa batch mới và nửa batch cũ. Backfeed có evaluation/delivery
sequence riêng theo key; không buộc chờ publication của reporting. Đối chiếu hai
luồng tại cùng source state, rules và as-of như mục 18.

### 5.1. KPI và định nghĩa phân tích

| KPI | Định nghĩa đề xuất |
|---|---|
| Required qualification pairs | Số distinct `(active pilot, required qualification)` trong phạm vi và publication đã chọn |
| Qualification coverage | Số required pairs có status `QUALIFIED` / tổng required pairs; không bỏ `EVALUATION_ERROR` khỏi denominator |
| Pilot readiness | Số active pilots có ít nhất một requirement, tập requirements hợp lệ và mọi required qualification `QUALIFIED` / số active pilots có ít nhất một required qualification |
| No-requirement / unresolved assignment | Báo riêng số pilots không có requirement hợp lệ và số pilots không resolve được assignment; không coi họ là ready |
| Technical uncertainty | Số required pairs `EVALUATION_ERROR` / tổng required pairs; lỗi assignment chưa resolve được báo riêng để tránh biến mất khỏi báo cáo |
| Actual flight seconds | Tổng seconds của eligible latest flights theo pilot và cửa sổ rule, sau dedup/tombstone; chỉ đổi sang giờ ở presentation |
| Flight shortfall | `max(minimum_seconds - eligible_seconds, 0)`; kèm coverage/error flag, không coi con số thiếu là kết luận đầy đủ nếu evidence có lỗi |
| Training gap count | Số requirement instances chưa đạt theo reason; không đếm số raw deliveries hoặc nhân theo role provenance |
| Freshness | Độ trễ từ source batch khả dụng đến publication, kèm checkpoint/run nguồn; phân biệt với event age và thời điểm kiểm tra nguồn gần nhất |

Denominator bằng 0 trả `null`/N/A, không trả 100%. Báo cáo phải hiển thị `as_of`,
publication, dữ liệu trễ/lỗi và phạm vi lọc. Bộ lọc mặc định gồm organization,
location, role, qualification, status và source batch. Unit attribution mặc định
theo organization/location tại publication đó; phân tích theo tổ chức lúc xảy ra
flight là policy khác và cần mô hình lịch sử tương ứng.

Ví dụ nghiệp vụ để kiểm thử độc lập: pilot cần 1.800 giây, có hai eligible flights
930 và 930 giây thì tổng 1.860, shortfall 0. Replay delivery không đổi tổng.
Correction một flight thành 600 giây làm tổng 1.530, shortfall 270. Tombstone
flight 600 giây làm tổng còn 930, shortfall 870. Các requirement LMS/ETR phải
được đánh giá riêng trước khi kết luận qualification tổng thể.

## 6. Yêu cầu data pipelines — PROPOSED

| ID | Yêu cầu | Tiêu chí nghiệm thu |
|---|---|---|
| PL-01 | Initial load đủ domain, registry và rule graph | Reconcile source keys/counts; raw lưu đầy đủ; không thiếu catalog hay mapping cần thiết |
| PL-02 | Incremental xử lý insert/update/deactivation/tombstone | Current state sau chuỗi changes khớp full rebuild trên cùng source state, rule và as-of |
| PL-03 | Replay/retry idempotent | Nạp lại cùng batch/page/events không tăng logical facts, totals hay required pairs; delivery attempts vẫn có audit |
| PL-04 | Pagination và checkpoint an toàn | Đọc đến `next_cursor=null`; retry page không mất/trùng logical records; chỉ commit checkpoint khi dữ liệu đã bền vững |
| PL-05 | Late arrivals/corrections | Event time cũ được nhận trong batch mới; cập nhật cửa sổ/aggregate bị ảnh hưởng; không chỉ lọc theo max departure time |
| PL-06 | Rule changes và thời gian | Rule version mới tạo evaluation mới; giữ publication cũ. Re-evaluation theo as-of vẫn chạy được khi không có source change |
| PL-07 | Reprocess/backfill có phạm vi | Chạy lại raw với parser/rule được chọn, có version/provenance; không sửa lịch sử công bố một cách âm thầm |
| PL-08 | Partial failure và publication | Lỗi một nguồn không tạo publication giả như đủ dữ liệu; giữ last-good version hoặc công bố degraded có coverage rõ |
| PL-09 | Schema evolution | Additive change được xử lý theo contract; missing required field/type change bị phát hiện trước serving; có version/migration plan |
| PL-10 | Lưu lịch sử business state | Tái dựng được organization/role/assignment tại publication cũ; correction không overwrite mất bằng chứng đã công bố |
| PL-11 | Daily reporting publication | Công bố serving data cho hai report 1 lần/ngày theo cutoff/timezone đã chốt; BI dev đọc cùng snapshot, có completeness manifest |
| PL-12 | Low-latency qualification backfeed | Detect change/time trigger → evaluate impacted keys → durable delivery → SQL commit; độc lập lịch reporting, có latency metrics |
| PL-13 | Hai luồng cùng qualification semantics | Cùng source checkpoint/rule/as-of cho cùng status; reporting rerun không đẩy old state đè current application state |

Có thể dùng ETL hoặc ELT; cần phân biệt raw, dữ liệu chuẩn hóa và dữ liệu phục
vụ nghiệp vụ về trách nhiệm và contract. Không bắt buộc tên layer hoặc công nghệ.

Ingestion timestamp, source event time, source updated time, evaluation as-of và
publication time phải có ý nghĩa riêng. Với Flight API mock không có change
token, snapshot polling + revision reconciliation là một phương án hợp lệ;
cursor phân trang không phải watermark xuyên các snapshot. Các trường hợp watermark
trùng timestamp, late correction và delete phải có test hoặc giới hạn công khai.

Historical query phải phân biệt “kết quả đã công bố khi đó” với “tính lại quá khứ
bằng dữ liệu biết hôm nay”. Mức đầu là bắt buộc; full bitemporal analytics là
EXTENSION. Artifact CDC cần kiểm tra đúng parent; branch local khác nhau không
được trộn thành một lịch sử tuyến tính mà chưa có quyết định xử lý.

## 7. Data quality và xử lý sự cố dữ liệu — PROPOSED

Platform phải tự phát hiện lỗi từ input, không chỉ sao chép DQ labels của generator.

| Nhóm | Kiểm tra tối thiểu | Hành vi mong muốn |
|---|---|---|
| Contract | Required fields, types, enum, null/empty, malformed JSON | Giữ raw, chỉ ra field/reason; không silent cast làm mất ý nghĩa |
| Identity | Missing/nonunique mappings, cross-source user conflict | Chặn nối sai người; issue có source refs và affected scope |
| Relational | PK/natural-key uniqueness, dangling FK/selector | Không nhân facts khi join; lỗi catalog/assignment không bị che |
| Temporal | Ambiguous timezone/date, invalid datetime, update-before-create | Parse theo metadata; lỗi chưa giải được không đi vào eligible evidence |
| Duration | Unit/colon/locale, negative/overflow/conflicting values | Canonical seconds có contract; ambiguous không tự đoán |
| Flight lifecycle | Duplicate delivery, revision conflict, tombstone | Dedup hợp lệ, quarantine conflict, loại delete khỏi totals |
| Training | ETR hierarchy/grades/status; LMS selectors | Missing evidence khác malformed evidence; không dùng sai target |
| Rules | Cycle, dangling nodes, invalid dates/operators/kinds | Kết quả technical error có giải thích; không báo business fail |

`INFO` variations hợp lệ khác lỗi DQ; clean không đồng nghĩa mọi qualification
đều đạt. Phân loại severity và quyết định block/quarantine/warn phải có policy
theo rule và affected product. Không áp dụng một ngưỡng phần trăm lỗi để cho
phép identity conflict lọt vào kết quả `QUALIFIED`.

Quarantine lưu raw reference, lỗi, parser/contract version, batch và trạng thái
xử lý. Có owner giả lập cho từng domain, hướng dẫn sửa tại source rồi replay;
không chỉnh trực tiếp raw để làm báo cáo đẹp. Cùng issue qua nhiều lần retry cần
correlation/dedup alert, đồng thời giữ lịch sử occurrence.

Issue tracking workflow/owner là product đích; generator không tự cung cấp đầy
đủ quy trình ticket, phê duyệt remediation hay notification. Dùng fixtures/local
notification sink cho thực hành nếu chưa tích hợp dịch vụ.

## 8. Monitoring, observability và SLO — PROPOSED

Operators phải phân biệt được pipeline success, data quality status và business
status. Job chạy thành công không chứng minh dữ liệu đầy đủ hoặc qualification đạt.

Theo dõi tối thiểu: source connectivity/checkpoint, records read/accepted/rejected,
duplicates/revisions/deletes, reconciliation, stage duration/failure/retry,
publication freshness, quarantine backlog, affected pilots/qualifications và chi
phí theo run/environment. Không gọi cursor executions là network round trips.

Mỗi run cần correlation IDs xuyên ingestion → transformation → DQ → publication.
Structured logs phải có context đủ điều tra, không log credentials hay payload
nhạy cảm. Dashboard có last-success, last-attempt, lag và trạng thái từng nguồn.
Alert phải có severity, owner, affected product, run link và runbook; kiểm thử
delivery bằng sink/test receiver thay vì tự gửi thông báo cho người thật.

Yêu cầu cadence/SLA đã được xác nhận theo từng luồng; các operational thresholds
khác dưới đây vẫn là **đề xuất cho lab nhỏ**, chưa phải kết quả benchmark. Đề xuất
incremental freshness chung p95 ≤ 15 phút ở phiên bản 1.1 đã **SUPERSEDED**, không
được dùng làm SLA backfeed hoặc thay cho lịch reporting:

| Hạng mục | Mục tiêu lab | Cách đo |
|---|---|---|
| Reporting — ACCEPTED cadence | Công bố serving data 1 lần/ngày | Theo business date/cutoff/deadline/timezone phải chốt; đếm successful/late/missing publications. Power BI refresh do BI team phối hợp riêng |
| Backfeed — ACCEPTED optimization objective | Latency càng nhỏ càng tốt; numeric SLO TBD | Từ source change khả dụng đến committed/readable target SQL state; đo p50/p95/p99/max, queue lag và stale keys theo tenant |
| Baseline load | ≤ 30 phút cho fixture nhỏ đã khai báo | Đo end-to-end; không suy rộng sang tải lớn |
| Detection | ≤ 5 phút sau failed run hoặc phát hiện critical DQ | Đến alert xuất hiện trong test sink |
| Logical replay correctness | 0 logical duplicates, 0 unexplained KPI delta | So sánh keys/hashes/KPI trước và sau replay |
| Recovery point (RPO) | Không mất acknowledged raw batch trong bài fault test | Đối chiếu durable raw + checkpoint với source manifest |
| Recovery time (RTO) | ≤ 60 phút cho lab nhỏ | Từ thời điểm bắt đầu recovery drill đến publication hợp lệ |

Batch không có change vẫn phải có kết quả kiểm tra nguồn; không dùng “không có
record mới” làm lý do giả mạo event freshness. Không cam kết high availability
hoặc exactly-once chỉ dựa trên việc replay một batch thành công.

## 9. Data governance, security và audit — PROPOSED

| ID | Yêu cầu | Bằng chứng nghiệm thu |
|---|---|---|
| GOV-01 | Catalog và ownership cho source/products | Có business definition, grain, owner/steward, classification, retention, SLA/SLO và contract version |
| GOV-02 | Lineage từ KPI về raw | Chọn một qualification status và truy được rule snapshot, evidence, canonical mapping, source refs và pipeline version |
| GOV-03 | Least privilege | Tách ingestion, transformation, consumer và deployment identities; consumer không sửa raw |
| GOV-04 | Manager scope enforcement | Query/serving thực tế lọc organization/location; test thiếu scope, revoked scope và nhiều scopes |
| GOV-05 | Phân loại và bảo vệ dữ liệu | Pilot IDs, email và kết quả đào tạo được phân loại; consumer thông thường bị hạn chế identifier chi tiết/raw |
| GOV-06 | Secrets và môi trường | Secrets ngoài Git/logs/artifacts; dev/test tách biệt; quyền và mã hóa khai báo qua cơ chế của stack |
| GOV-07 | Retention và cleanup | Chính sách riêng cho raw, curated, quarantine, audit; dry-run, scope rõ và giữ bằng chứng cần nghiệm thu |
| GOV-08 | Audit thay đổi | Theo dõi contract/rule/code/deployment/access changes; lịch sử đủ tái dựng một publication |

Scope manager được hiểu là hợp các cặp `(organization_id, location_id)` active;
không lấy tích chéo hai danh sách organization và location để mở rộng quyền.
Quyền xem lịch sử đề xuất kiểm tra theo scope hiện hành và unit của publication;
khi scope bị thu hồi phải mất quyền truy vấn tương ứng, không giữ grant cũ.
Đây là policy đích cần xác nhận khi chọn serving mechanism, không phải RLS engine
đã có trong generator.

Dữ liệu thực hành dùng identifiers giả và domain `example.test`; vẫn thực hành
masking/access control như dữ liệu có tính nhạy cảm. Retention lab đề xuất: raw,
curated và quarantine 30 ngày; audit/publication manifests 90 ngày. Cần giữ source
evidence hoặc archive tương ứng nếu còn yêu cầu tái dựng báo cáo; không hứa full
rebuild 90 ngày khi chỉ còn raw 30 ngày. Đây không phải nghĩa vụ pháp lý hàng không.

## 10. CI/CD, IaC và quản trị thay đổi — PROPOSED

Doanh nghiệp muốn một môi trường thực hành có thể tạo lại, kiểm thử và bàn giao
cho Data Engineer khác mà không dựa vào các thao tác console không ghi nhận.

- **DEL-01:** infrastructure, configuration, grants, pipeline definitions và
  product contracts được version control. Tài nguyên không hỗ trợ IaC phải có
  bootstrap/runbook và lý do; không giấu bước thủ công.
- **DEL-02:** CI kiểm tra syntax/config/IaC, transformation logic, contracts,
  deterministic fixtures, DQ, replay và negative access tests. Default CI không
  cần credentials production; integration tests dùng môi trường test riêng.
- **DEL-03:** IaC plan/preview và schema impact phải review được trước apply.
  Breaking changes có migration/compatibility plan; tách deploy code khỏi backfill.
- **DEL-04:** cùng artifact/version được promote dev → test; đường lên production
  có thể mô tả như mô phỏng nếu lab chỉ có dev/test. Không cần tạo production thật.
- **DEL-05:** lưu commit, build/artifact version, config, infrastructure version,
  test evidence và data publication liên quan cho mỗi release.
- **DEL-06:** rollback code/IaC và recovery dữ liệu là hai quy trình riêng. Chứng
  minh quay về version tốt hoặc forward-fix mà không làm mất raw/history.
- **DEL-07:** tài nguyên lab có environment/project/owner tags, budget threshold,
  cleanup plan và cách phát hiện drift phù hợp stack. Ngân sách là tham số phải
  chốt trước khi tạo tài nguyên có phí; không gán số chi phí khi chưa đo.

Agent không cần đổi generator để đáp ứng CI/CD của platform. Mọi thay đổi source
contract cần đề xuất riêng, version hóa và cập nhật generator/tests đồng bộ.

## 11. Scenario nghiệm thu end-to-end

Các scenario có tên trong bảng đã đối chiếu `scenarios.py`. Dataset cụ thể và
expected outcomes phải lấy từ run thực tế; không giả định mỗi scenario làm đổi
status tổng thể khi các requirement khác vẫn chưa đạt.

| ID | Tình huống / nguồn kích hoạt | Kết quả phải chứng minh |
|---|---|---|
| AT-01 | `initial --profile clean` | Reconcile đủ nguồn, không critical contract error; tạo DP-01..07; clean có thể chứa business fail hợp lệ |
| AT-02 | `pilot_created`, `pilot_moved`, `pilot_deactivated` qua child runs | Requirements/state/summary cập nhật đúng; publication cũ giữ nguyên; current view không tiếp tục coi inactive pilot là ready |
| AT-03 | `assessment_passed`, `assessment_failed`, `assessment_section_corrected`, `exam_result_changed` | Requirement đúng target phản ánh change; grade/status lỗi khác business fail; không gộp attempts làm sai kết quả |
| AT-04 | `flight_record_added`, `flight_record_corrected`, `flight_record_deleted` | Latest evidence và seconds đúng; tombstone không xóa mất raw; aggregates/qualification được tính lại |
| AT-05 | `duplicate_flight_delivery` và replay cùng batch | Tăng delivery audit nếu có, không tăng logical flights/seconds/KPI |
| AT-06 | `late_arriving_flight` | Nhận flight event time cũ, cập nhật window liên quan; không bỏ vì ingestion watermark |
| AT-07 | `pilot_mapping_missing`, `pilot_mapping_added`, `cross_system_pilot_conflict` | Không nối sai người; issue/coverage rõ; mapping sửa xong có thể reprocess raw |
| AT-08 | `ambiguous_datetime`, `ambiguous_flight_duration`, `qualification_evaluation_error` | Raw giữ nguyên; tự phát hiện lỗi; không biến lỗi parse/JSON thành `NOT_QUALIFIED` hoặc `QUALIFIED` |
| AT-09 | `qualification_rule_updated`, `qms_graph_cycle` | Rule version và impacted evaluations truy vết được; cycle là technical error; báo cáo cũ không đổi |
| AT-10 | `DQ-DT-001`, `DQ-FLT-001`, `DQ-FLT-017` so với các mã ERROR | Variations/replay hợp lệ không tự thành lỗi; severity và canonical values theo contract |
| AT-11 | EXTENSION: giả lập timeout, 429/5xx, crash sau ghi raw/trước checkpoint | Retry/restart không mất hoặc nhân logical records; alert, checkpoint và publication đúng |
| AT-12 | EXTENSION: thay fixture scopes, thêm manager ngoài phạm vi, revoke scope | Access enforcement thật, gồm negative tests; không chỉ kiểm tra một cột scope trong bảng |
| AT-13 | EXTENSION: schema additive/breaking changes và parser upgrade | Contract gate hoạt động; reprocess có version; không sửa raw hay publication cũ |
| AT-14 | Cùng source state/rules/as-of, so incremental với full rebuild | Logical keys, required pairs, evidence totals và qualification statuses khớp hoặc có discrepancy đã phê duyệt |
| AT-15 | EXTENSION: giả lập sự cố và tái dựng môi trường từ IaC + durable data | RPO/RTO có số đo, runbook dùng được; không phụ thuộc dữ liệu tạm chỉ có trên máy cũ |
| AT-16 | EXTENSION: giữ nguyên source, dịch evaluation as-of qua biên window/validity | Flight hết rolling window hoặc rule hết hạn được phản ánh dù không có source update |
| AT-17 | Hai hãng có cùng source IDs/run IDs, sources và targets riêng | Không overwrite/join chéo; principal hãng A không đọc/ghi/list được data, logs, quarantine, backup hoặc cache của B |
| AT-18 | Cùng employmentdate/as-of nhưng mapping hãng A/B khác nhau | `years_employed` bằng nhau nhưng seniority đúng từng hãng; policy provenance đầy đủ |
| AT-19 | Ngay trước/đúng anniversary, ngày 29/02 và band boundaries | Tính completed years và mapping interval chính xác; future/null/malformed không thành junior mặc định |
| AT-20 | Upgrade mapping, correction employmentdate, hoặc chỉ đổi as-of | Current seniority được tính lại; historical publication cũ giữ nguyên; không cần source CDC để tuổi nghề tăng |
| AT-21 | Tenant onboarding, failure, cleanup/restore hoặc mapping bị thiếu | Chỉ tenant mục tiêu bị tác động; thiếu mapping không dùng rules hãng khác; IaC/data routing fail closed |
| AT-22 | Daily reporting batch cho learning + qualification | Đủ detail/dimensions/keys/coverage cho BI dev; publication nhất quán 1 lần/ngày; cutoff/deadline được kiểm tra, không yêu cầu DE xây Power BI report |
| AT-23 | Source correction, rule change, revocation hoặc timed expiry giữa hai daily batches | Backfeed cập nhật SQL đích không đợi reporting; đo source-to-target commit latency và đối chiếu current evaluation |
| AT-24 | Target SQL down, retry, duplicate delivery, crash sau commit/trước ack và delivery đảo thứ tự | Không mất status update; retry idempotent, older evaluation không đè current/revoked state; backlog/freshness cảnh báo; recovery chỉ tác động tenant đúng |
| AT-25 | Chụp reporting/backfeed tại cùng checkpoint/rule/as-of | Status bằng nhau, khác biệt thời điểm hiện tại được giải thích; daily backfill không ghi đè target current state |
| AT-26 | Pilot inactive, required qualification bị gỡ, mapping lỗi hoặc evaluation error | App không tiếp tục hiểu stale QUALIFIED là current hợp lệ; xử lý bằng target lifecycle/error contract đã chốt, có audit và negative tests |

`dq-inject` và các child commands cần parent/scenario đúng contract. Initial
`clean` không nhận DQ scenarios; profile `targeted` cần scenario cụ thể. Các mã
INFO vẫn có thể đi qua catalog DQ như cơ chế thử nghiệm, không đổi severity thành
ERROR. Các failure injection ở AT-11..16 cần harness/fixtures riêng khi nguồn
không có scenario tương ứng; không mặc nhiên coi mock API có sẵn fault switches.

Một test case phải ghi: input source run/hash, parent, manifest/generation clock,
rule/parser version, as-of, thao tác, expected result, observed result và artifact
chứng minh. Expected result gồm cả assertion nhỏ tính tay và reference oracle;
không chỉ gọi lại cùng một transformation rồi so sánh với chính nó.

## 12. Quy mô, hiệu năng và chi phí thực hành

Không có yêu cầu enterprise-scale đã được xác nhận. Bắt đầu với `pilot_count`
nhỏ; config hiện mặc định 12 pilots. Với fixture mặc định, source sinh 18 ETR
assessments, 54 sections và 216 items; không giả định mọi pilot có cùng số targets.

Trước bài load test lớn, khai báo số pilots, records/domain, số revisions,
incremental size, lịch sử lưu, tài nguyên, concurrency và budget. Đo source
generation riêng với platform ingestion/processing. Generator hiện materialize
dataset trong RAM; adapter `batch_size` không bảo đảm streaming hay giới hạn RAM
toàn pipeline. Không chỉ tăng `pilot_count` rồi tuyên bố kiểm thử tải thành công.

Báo cáo hiệu năng tối thiểu có end-to-end latency, throughput, peak memory khi đo
được, bytes/rows scanned, retries và chi phí thực tế hoặc estimate có giả định.
Ưu tiên chứng minh incremental không full-refresh không cần thiết, nhưng mọi tối
ưu phải giữ parity và có bằng chứng số liệu.

## 13. Deliverables và Definition of Done

| Deliverable | Nội dung có thể review |
|---|---|
| Business baseline & ADRs | Stack/mode/phạm vi, assumptions, quyết định latest-attempt/time/scope, deviations và gap register |
| Source assessment | Contract inventory, extraction strategy, registry delivery, source availability và lineage |
| Data model & products | Tenant boundaries, grain/keys, raw/history/current semantics, DP-01..10, seniority policies; BI serving contracts cho learning/qualification và SQL application read model |
| Pipelines | Initial/incremental/replay/backfill; daily reporting publication và low-latency backfeed có checkpoints/recovery riêng |
| DQ & governance | Rule catalog, quarantine, ownership, catalog/lineage, grants/masking và negative tests |
| Observability | Dashboard/queries, metrics, alert test sink, SLO evidence và runbooks |
| Delivery automation | IaC, CI/CD, environment config templates, deployment/release evidence và cleanup |
| Acceptance pack | AT-01..26 results trong phạm vi, daily publication evidence, target SQL correctness/latency, oracle comparison, limitations và cost/performance report |

Bài thực hành hoàn thành khi người khác có thể làm theo README để tạo môi
trường, ingest baseline và child runs, xem products, gây lỗi có kiểm soát, quan
sát ảnh hưởng, recover/replay và kiểm tra kết quả mà không hỏi lại tác giả về
các bước ngầm. Chạy được một notebook hoặc một lần initial load chưa đủ.

Chia delivery để mỗi giai đoạn có kết quả kiểm chứng được:

1. **Nền tảng nghiệp vụ:** artifact mode, source contracts, DP-01..05, KPI, DQ và
   parity bằng fixture nhỏ; chốt BI serving và target SQL contracts; basic CI,
   local deployment/logs và minimal daily/backfeed prototypes.
2. **Data platform vận hành được:** DP-06..10, integration mode nếu đã có source
   endpoints; nghiệm thu daily BI serving và independent SQL backfeed, cùng
   orchestration/checkpoints, governance, IaC/CD, alert, latency và recovery.
3. **Mở rộng thực hành:** scale, fault/schema/access test harness, tối ưu chi phí,
   hoặc triển khai lại một stack khác với cùng acceptance suite.

AT-01..10 và AT-14 là lõi; AT-11..13, AT-15..16 cần bổ sung harness ở giai đoạn
vận hành. Nếu thu hẹp phạm vi, ghi `DEFERRED` kèm lý do và tác động; không đánh
dấu toàn bộ platform hoàn thành khi chưa kiểm chứng access/recovery/deployment.
AT-17..21 là nghiệm thu bổ sung bắt buộc khi triển khai platform multi-tenant;
AT-18..20 dùng downstream fixtures/policies, không phải generator scenarios mới.
AT-22..26 nghiệm thu hai luồng chính, dùng SQL target test/fixtures của platform;
không phải chức năng backfeed hiện đã có của mockgen. DE hoàn thành phần reporting
khi serving layer được nghiệm thu theo contracts, không phụ thuộc BI dev đã vẽ report.

## 14. Hướng dẫn giao việc cho AI agent tiếp theo

Có thể dùng nguyên khối sau làm prompt khởi đầu:

```text
Bạn là Data Engineer xây dựng Pilot Training & Qualification Data Platform.
Đọc project_requirements/data_platform_business_requirements.md, AGENTS.md,
docs/ai-context/CURRENT_STATE.md và contracts/source code liên quan.
Đọc thêm project_requirements/data_platform_data_model.md. Nhà cung cấp phục vụ
nhiều hãng có databases và custom mappings riêng. Dùng tenant data planes tách
biệt, không lấy organization_id làm tenant, không gom business data mặc định.
Tính seniority từ employmentdate/as-of bằng policy version riêng cho từng hãng;
seniority chưa phải điều kiện qualification.
Xây hai luồng: daily serving layer cho Power BI pilot learning status và pilot
qualification status reports (BI dev làm reports); qualification backfeed vào
SQL Server đích với latency thấp nhất khả thi. Backfeed không đợi daily mart.
Chốt cutoff/deadline/timezone reporting và target SQL contract; đo latency rồi
đề xuất numeric SLO, không tự gán 15 phút. Hai luồng cùng semantics nhưng có
publication/checkpoint/recovery riêng; daily backfill không ghi đè app current state.

Hãy triển khai platform theo kết quả nghiệp vụ và acceptance criteria trong tài
liệu, trên stack/môi trường tôi cung cấp. Không coi các yêu cầu PROPOSED là chức
năng đã có; hãy ghi lại baseline lựa chọn và gap cần xử lý.

Trước khi code, xác minh source contract, ingestion mode, registry delivery,
grain/keys, rule/as-of/latest-attempt policy và phạm vi nguồn thực sự khả dụng.
Lập requirement-to-design-to-test traceability và chia milestones có nghiệm thu.
Chỉ hỏi các quyết định thật sự ảnh hưởng nghiệp vụ, môi trường hoặc chi phí mà
chưa thể xác minh từ context. Có thể tiến hành phần local/reversible độc lập.

Tự xây ingestion/transformation/DQ/qualification products từ source inputs.
Dùng generator-derived outputs và audit trong validation riêng; không đọc chúng
để tạo kết quả platform. Preserve raw; không tự sửa generator hay dữ liệu lỗi có
chủ đích. Mọi gap nguồn cần proposal/fixture/extension có scope rõ.

Triển khai đến khi có code, automated checks và bằng chứng end-to-end cho phạm
vi được giao; bàn giao IaC/CI/CD, governance, monitoring và recovery cùng data
products. Báo rõ test đã chạy, phần chưa kiểm chứng, chi phí và các deviations.
```

Thông tin người học bổ sung khi bắt đầu mỗi lần triển khai: stack, workspace/repo
đích, account/environment test, mode, lịch chạy, scale, ngân sách và milestone.
Nếu chưa có account hoặc budget, agent vẫn có thể thiết kế và kiểm chứng local;
chưa tạo tài nguyên có phí dựa trên giả định.

## 15. Quyết định còn mở và bằng chứng nguồn

### 15.1. Cần chốt khi triển khai

| Quyết định | Baseline đề xuất / giới hạn |
|---|---|
| Stack và compute/storage/orchestrator/serving | Chọn theo bài thực hành; business contracts không đổi theo vendor |
| Latest assessment/exam | Parity dùng snapshot order; timestamp-based policy cần contract có tie-breaker, version và expected differences |
| Evaluation as-of và rule-change effect | Dùng manifest clock cho parity; scheduled current evaluation có version riêng; không tự hồi tố publication |
| Scope và historical access | Policy đề xuất ở mục 9, cần đối chiếu khả năng serving và test negative cases |
| Reporting cutoff/deadline/timezone | Cadence 1 lần/ngày đã ACCEPTED; giờ công bố, data cutoff, calendar và late-source policy chưa chốt; Power BI refresh thuộc BI team |
| Backfeed latency SLO | Mục tiêu thấp nhất khả thi đã ACCEPTED; đo source-to-target latency theo source capabilities/load/cost rồi chốt numeric percentile/threshold |
| Target SQL/application contract | Cần schema/keys/client pilot mapping/enums, write authority, transaction/read visibility, inactive/error/stale handling; không đoán từ mock source DDL |
| Retention/scale/operational SLO | Ngoài cadence/mục tiêu hai luồng vừa xác nhận, các số khác vẫn là đề xuất lab |
| CDC từ SQL và graph | Xác minh quyền/capabilities nguồn; chọn native CDC, watermark hoặc snapshot diff có giới hạn được ghi rõ |
| Evidence đã parse lỗi nhưng chưa map được pilot | Không đoán ảnh hưởng; công bố identity/DQ uncertainty, không coi phần thiếu là bằng chứng đủ để qualify |
| Certification/manual review/validity fixtures | Logic có trong evaluator nhưng không giả định có sẵn end-to-end generator scenario cho mọi tình huống |
| Concurrent batches và multi-source consistency | Mặc định một publication lineage được điều phối; concurrency/distributed consistency cần thiết kế và fault tests riêng |
| Report vs operational consistency | Daily report là snapshot theo cutoff; app là latest applied state. Reconcile tại cùng source/rule/as-of, không ép hai thời điểm khác nhau phải giống |

### 15.2. Nguồn tham chiếu trong repo

- [Đặc tả generator](cross_platform_mock_data_generator_spec.md): mục tiêu và domain ban đầu.
- [Source contracts](../docs/contracts.md), [config mẫu](../configs/base.yaml): current synthetic contract và defaults.
- [Generators](../src/mock_data/generators.py), [qualifications](../src/mock_data/qualifications.py): catalog, identity, role assignments và evidence targets.
- [QMS evaluator](../src/mock_data/qms.py), [ETR](../src/mock_data/etr.py): trạng thái và quy tắc đánh giá hiện tại.
- [Normalization pipeline](../src/mock_data/pipeline.py): raw/derived, parsing, revision và quarantine.
- [Scenarios](../src/mock_data/scenarios.py), [DQ catalog](../src/mock_data/dq.py): tên scenarios, profiles và severity.
- [Change events](../src/mock_data/events.py), [orchestration](../src/mock_data/orchestration.py): lifecycle, delta và generation clock.
- [Flight API](../src/mock_data/adapters/flight_api.py): pagination và giới hạn giao diện mock.
- [Lifecycle tests](../tests/test_lifecycle.py), [QMS tests](../tests/test_qms.py), [training requirements tests](../tests/test_training_requirements.py): cases để thiết kế parity checks.

Các SLO và kiến trúc platform là đề xuất; chưa deploy hoặc kiểm chứng cloud trong
lần cập nhật này. Bằng chứng kiểm thử generator xem project memory/ báo cáo thay
đổi; agent triển khai phải thu thập validation evidence mới cho platform của mình.

## 16. Tenant isolation và custom transformation

### 16.1. Business boundaries — ACCEPTED

Mỗi hãng sở hữu source SQL databases và graph database riêng. Mapping danh tính,
qualification rules và seniority policy chỉ có hiệu lực trong hãng đó. Không
chia sẻ bản ghi employee, evidence, graphs hoặc bảng dim/fact chứa business data
giữa các hãng theo mặc định. Giữ `tenant_id` ở metadata đích để kiểm tra routing,
nhưng chỉ thêm tenant filter vào bảng chung chưa đáp ứng yêu cầu lưu trữ riêng.

Default đề xuất là **silo data plane theo hãng**: storage/database, catalog và
security principals riêng; strict tier còn tách account/subscription/workspace,
compute/network theo cam kết của khách. Control plane có thể dùng chung code,
IaC templates và metadata vận hành tối thiểu đã cho phép. Không ghi raw, employee
IDs, graph rules hoặc nội dung custom mapping của hãng vào shared control plane.

Cách ly phải bao phủ Bronze/Silver/Gold, checkpoint/state, temp/spill, logs chứa
dữ liệu, DQ/quarantine, BI extracts, query caches, exports và backups. Schema hay
folder riêng trong cùng database/storage là phương án logical isolation; chỉ
dùng khi hãng xác nhận chấp nhận boundary đó. Không hứa physical disk separation
chỉ vì tạo database hoặc bucket khác trên managed service.

Onboarding một hãng khai báo tenant identifier, source connections bằng secret
references, target isolation resources, business timezone, policies, owners,
retention/SLO và release version. Tenant context phải lấy từ authenticated job
configuration; không tin `tenant_id` do một source row tự khai báo. Source/target
binding mâu thuẫn phải chặn trước ghi dữ liệu. Một tenant failure hoặc cleanup
không làm mất data/checkpoint của tenant khác.

### 16.2. Seniority contract — ACCEPTED input; PROPOSED semantics/mapping

Source TMDS có `employmentdate`, ngày bắt đầu làm việc tại hãng đang xét; v5 sinh
giá trị cho mọi user. Không lưu derived seniority trong source, không dùng
`created_at` thay employmentdate. Rehire/leave gaps/kinh nghiệm ở hãng khác cần
contract riêng, chưa được tự cộng vào seniority.

Baseline downstream đề xuất:

1. Chuyển evaluation instant thành `as_of_date` theo business timezone của hãng.
2. `years_employed` là số **năm tròn đã hoàn thành**, tính theo anniversary ngày
   tuyển dụng; không dùng số ngày chia 365 hay chênh lệch calendar year đơn thuần.
3. Với hire date 29/02, policy mẫu chọn anniversary 28/02 trong năm không nhuận;
   lưu lựa chọn này trong calculation policy/version, không phụ thuộc ngầm engine SQL.
4. Chọn duy nhất policy có hiệu lực tại as-of, rồi band thỏa
   `min_years_inclusive <= years_employed < max_years_exclusive`; max null là vô hạn.
5. Missing/invalid/future employmentdate → không có years/seniority và có DQ reason.
   Missing/overlap/gap policy → configuration error; không fallback tenant khác
   hoặc tự gán Junior. Severity/affected publication được công khai.

Mapping mẫu do người học yêu cầu đề xuất, chưa phải HR policy thật:

| Hãng | Completed years | Seniority code | Label |
|---|---|---|---|
| AIRLINE-A | `[0, 3)` | A-JUNIOR | Junior |
| AIRLINE-A | `[3, 10)` | A-EXPERIENCED | Experienced |
| AIRLINE-A | `[10, +∞)` | A-SENIOR | Senior |
| AIRLINE-B | `[0, 5)` | B-JUNIOR | Junior |
| AIRLINE-B | `[5, 15)` | B-EXPERIENCED | Experienced |
| AIRLINE-B | `[15, +∞)` | B-SENIOR | Senior |

Ví dụ employmentdate `2022-11-17`, as-of `2026-11-17`: 4 năm → A-EXPERIENCED,
B-JUNIOR; ngày `2026-11-16` vẫn chỉ có 3 năm. Employmentdate `2014-11-17` tại
cùng as-of là 12 năm → A-SENIOR, B-EXPERIENCED. Hire `2024-02-29` đạt 1 năm
vào `2025-02-28` theo calculation policy mẫu.

Policy có `policy_id`, version, effective-from/until, approval/release reference,
timezone, anniversary convention và bands; không overlap theo tenant/date.
Mapping mới hoặc correction employmentdate phải chạy lại affected current data;
anniversary xảy ra dù source không thay đổi nên cần scheduled evaluation.
Publication lưu policy version/as-of, lịch sử cũ không đổi. Seniority phục vụ
phân tích và grouping; chưa có yêu cầu thay qualification rules theo seniority.

## 17. Data model và architecture đề xuất

Đọc [Data model proposal](data_platform_data_model.md) cho isolation choices,
Mermaid diagrams, Bronze/Silver/Gold contracts, normalized Silver, Gold star
schemas, bridges/SCD2, seniority policy tables và domain data marts. Phần này là
thiết kế đề xuất cho downstream; không phải các bảng mockgen đã tạo.

Baseline: silo data plane theo tenant; medallion bên trong từng silo; Gold dùng
star schema và conformed dimensions trong phạm vi hãng; snowflake schema dùng
chọn lọc nếu có lợi ích rõ; domain ownership theo tinh thần data mesh. Data mesh
là mô hình ownership/vận hành, không thay thế dimensional modeling hay tenant
isolation. Cross-airline analytics chỉ được bổ sung khi có yêu cầu/chấp thuận
riêng; không mặc định tạo một central warehouse chứa business data mọi hãng.

## 18. Hai luồng nghiệp vụ chính — ACCEPTED scope, PROPOSED contracts

### 18.1. Reporting: serving layer cho BI dev, 1 lần/ngày

Data Engineer cung cấp dữ liệu cho **pilot learning status report** và **pilot
qualification status report**; BI dev chịu trách nhiệm xây Power BI reports và
triển khai semantic model/DAX/report visuals. DE cung cấp business definitions,
keys/relationships, typed fields, query examples, expected results và access
contract để hai bên thống nhất số liệu, không chỉ bàn giao một dump raw.

| Serving contract | Grain/report-facing data | Dữ liệu tối thiểu cần đủ |
|---|---|---|
| Pilot learning status | Tenant × pilot × learning target × report date/publication; attempt/section/item drill-down ở bảng con có grain riêng | Required/assigned course, exam, assessment template; enrollment/progress/attendance, completion, attempt/result/score/grades, missing/pending/failed/error reasons; org/location/roles/seniority và source refs |
| Pilot qualification status | Tenant × pilot × required qualification × report date/publication | Required vs evaluated, status, rule version, requirement outcomes/gaps, Flight/training evidence, technical/coverage state, as-of/source cutoff và profile dimensions |

Learning targets cần xuất hiện kể cả khi chưa có evidence để report thấy khoảng
thiếu; dùng explicit expected-target resolver rồi nối evidence, không chỉ report
những người có exam/assessment rows. Source enrollment/progress/exam/assessment
statuses có semantics khác nhau; derived learning status cần mapping/version
được duyệt, không tự biến mọi trạng thái thành một cờ completed hoặc qualification.

Cadence đã chốt: **1 lần/ngày**. Chưa có giờ công bố, timezone, data cutoff và
quy tắc ngày nghỉ được chốt. Agent phải ghi nhận các tham số đó trước nghiệm thu
SLA; không tự hiểu là mọi record phải được xử lý trong vòng 24h từ event time.
Publication lưu report date, evaluation as-of, source checkpoints/cutoff, rule/
mapping versions, completeness/DQ summary và ready timestamp. Daily report cũ
bất biến; corrected rerun dùng publication mới và có selection rule rõ cho BI.

Biện pháp đề xuất: stage dữ liệu, validate/reconcile rồi switch active report
publication atomically ở boundary đã thống nhất. Nếu nguồn trễ/missing thì
last-good/degraded publication phải có freshness/coverage rõ, không giả mạo
successful complete daily publication. Import/DirectQuery, gateway và Power BI
refresh orchestration do hai bên thống nhất; SLA DE đo đến serving data ready,
thời điểm report hiển thị mới cần phối hợp refresh contract với BI team.

### 18.2. Backfeed: qualification status vào target SQL Server

Client application đọc qualification status từ SQL Server đích được chỉ định.
Platform chịu trách nhiệm tính đúng và ghi status tới target; chưa có yêu cầu
backfeed learning status, raw evidence hoặc toàn bộ dimensional warehouse vào app.
Target có thể khác SQL Server source; cần connection/DB/schema/write ownership
riêng theo tenant contract, không suy ra từ source mappings.

Luồng logic đề xuất: source changes/time triggers → canonical normalization và
DQ → reevaluate impacted pilot/qualification keys → durable pending delivery →
target SQL transaction → ack/reconciliation. Tính lại khi Flight/training/source
identity/assignments/rules đổi, qualification hết hạn/rolling window dịch chuyển;
không chỉ khi source có CDC. Seniority changes chỉ ảnh hưởng qualification nếu
sau này có rule được duyệt dùng seniority, không tự thêm dependency.

Độ trễ mong muốn: **càng nhỏ càng tốt**, đồng thời giữ correctness và isolation.
Agent phải khảo sát source CDC/polling/graph/API capabilities, volume và chi phí;
chọn incremental/event-driven/micro-batch thích hợp, đo rồi đề xuất SLO bằng số.
Không mặc định SLA 15 phút, cũng không cam kết real-time khi source chỉ có daily
extract. Tách source availability lag khỏi processing/delivery lag để thấy rõ
bottleneck thay vì chỉ đo job duration.

Logical target contract đề xuất, **chưa phải physical columns của client DB**:

- Unique key: tenant context + **client pilot identity** + qualification identity;
  mapping từ canonical pilot sang app ID phải explicit, không giả định bằng TMDS ID.
- Payload: qualification business status, evaluation ID/as-of, rule snapshot/version,
  input/checkpoint reference, authoritative per-key state sequence và content hash.
- Reliability metadata: computed/sent/applied timestamps, delivery correlation,
  freshness/coverage và technical state; layout nằm ở target hoặc delivery audit
  tùy schema client cho phép. Không coi thời điểm gửi là đã commit thành công.
- Lifecycle: pilot inactive, required qualification bị gỡ, revoked/expired hoặc
  evaluation error cần explicit agreed handling. Không để app âm thầm tiếp tục
  sử dụng stale `QUALIFIED`; không tự hard-delete, giữ status cũ làm current,
  hoặc ép technical error thành business fail để khớp enum target.

Delivery phải idempotent; replay/timeout sau commit không tạo duplicate status
rows. Older state không overwrite newer state, kể cả retry/backfill/reordering.
So sánh authoritative sequence theo key trong cùng transaction với update;
không dùng riêng timestamp đến nơi hoặc chuỗi rule_version để xác định thứ tự.
Pending state và ack/checkpoint phải phục hồi được sau crash. Có thể giữ append-only
evaluation history riêng và current read model cho app; không yêu cầu app query
star-schema facts để đọc một qualification status.

Target outage phải giữ backlog có audit/retry, expose stale/apply state, phục
hồi đúng tenant và đúng thứ tự. Gate publish/reconcile không được thông báo
successful delivery trước khi DB commit. Reconciliation định kỳ tìm missing,
duplicate, stale hoặc mismatched target rows. Write authority, conflict handling
nếu client cũng sửa rows, status enums và transaction grouping cần chốt trước
khi viết integration; không tự overwrite external changes.

### 18.3. Shared business logic, independent publication và recovery

Hai luồng dùng chung identity resolver, qualification semantics, normalization
và rule/policy versioning. Có thể dùng chung canonical state/evaluation history;
backfeed lấy operational evaluation sẵn sàng mà không phụ thuộc full Gold refresh.
Reporting xây daily snapshot từ canonical/evaluation state tại cutoff; historical
cutoff có thể cần evaluate lại bằng input/rule/as-of tương ứng.

SQL app hiện tại có thể mới hơn report hôm nay: đó là khác biệt freshness, không
tự coi là lỗi nghiệp vụ. Chỉ assert equality khi source checkpoint, input hash,
rule/policy versions và as-of tương đương. Reporting failure không chặn backfeed;
target SQL outage không chặn daily reporting nếu canonical inputs đủ. Hai nhánh
giữ publication/checkpoint/recovery state riêng, không hứa distributed transaction.

Mọi backfill/report rerun mặc định chỉ tạo analytical outputs; muốn sửa current
target phải reevaluate trên authoritative current state và đi qua delivery gate.
Khi target là một phần hệ thống cũng được ingest, phải khai báo source/target
ownership và loại feedback loop qua lineage, không ingest nhầm output làm evidence.

Mockgen hiện chỉ tạo source fixtures và reference evaluations; `publish --target
sources` ghi mapped **source entities**, không phải qualification backfeed của
client application. Yêu cầu mới cập nhật platform spec/model, không thay đổi
source contract v5, qualification business rules hoặc triển khai sink remote.
