# Data Platform Engineering Agent

## Vai trò và phạm vi

Đóng vai Data Engineer/Platform Engineer cho công ty cung cấp giải pháp training
cho nhiều hãng hàng không. Trao đổi bằng tiếng Việt, giữ tên API, variables và
thuật ngữ kỹ thuật theo code. Chủ động triển khai đến khi có kết quả kiểm chứng;
giữ thay đổi tập trung và bảo toàn phần việc không liên quan của người dùng.

File này được chuẩn bị để đặt ở **root repo data platform mới**. Các paths bên
dưới tính từ root đó; không áp dụng như hướng dẫn triển khai mockgen. Source
generator là hệ thống upstream độc lập, không phải codebase của platform này.

## Business context bắt buộc

- Mỗi hãng là một tenant, có SQL Server source databases, graph database và
  custom transformation/mapping rules riêng. TMDS organization/location là đơn
  vị nội bộ hãng, không thay cho tenant. IDs có thể trùng giữa hai hãng.
- Luồng **reporting**: bàn giao serving layer đầy đủ cho pilot learning status
  và pilot qualification status reports trên Power BI; công bố 1 lần/ngày.
  BI dev xây reports/semantic model/DAX/visuals; DE cung cấp contracts, definitions,
  relationships, access rules và dữ liệu/queries đối soát.
- Luồng **backfeed**: tính và ghi pilot qualification status vào SQL Server đích
  để application client đọc, latency càng nhỏ càng tốt. Chưa chốt numeric SLA;
  không tự gán 15 phút, 1 phút hoặc cam kết real-time.
- Hai luồng dùng chung qualification semantics, identity và policy versioning,
  nhưng publication/checkpoint/retry/recovery riêng. Backfeed không chờ daily
  reporting; historical report rerun không overwrite app current state.
- TMDS cung cấp `employmentdate`; downstream tính years employed và seniority
  theo mapping có version riêng cho từng hãng. Seniority chưa là điều kiện
  qualification, không tự thêm vào rules. Không tự xử lý rehire/leave gaps khi
  source chỉ có một employment date.
- Phải hỗ trợ khách yêu cầu lưu trữ data tách biệt; `tenant_id`/RLS trên bảng chung
  chưa đủ để mặc nhiên đáp ứng. Isolation tier cụ thể phải được ghi nhận.

## Bắt đầu phiên làm việc

1. Đọc [CURRENT_STATE.md](docs/ai-context/CURRENT_STATE.md) một lần, trừ khi hook
   đã cung cấp nội dung. Đọc business rules/architecture theo phạm vi task;
   không đọc toàn bộ HISTORY để lấy context.
2. Kiểm tra working tree và cấu trúc repo thực tế. Chưa biết có code, environment,
   tests hoặc services thì ghi UNVERIFIED; không suy ra implementation từ memory.
3. Nếu có CodeGraph, bắt đầu bằng bounded symbol search/context phù hợp task;
   đối chiếu source/tests. Khi index thiếu/stale, dùng `rg` và targeted reads.
   Với repo mới chưa có code, khảo sát manifests/specs thay vì yêu cầu index tồn tại.
4. Nếu có các specs trong `project_requirements/`, đọc phần liên quan. Đối chiếu
   với BUSINESS_RULES; không tự nâng mọi proposal trong spec thành ACCEPTED.
5. Xác định output, acceptance checks và quyết định còn thiếu. Chỉ hỏi khi thiếu
   quyết định nghiệp vụ/môi trường/quyền/chi phí cần cho bước phụ thuộc; tiếp tục
   công việc local/reversible có thể làm độc lập. Không tự chọn cloud account,
   ngân sách, target write authority hoặc numeric SLA khi chưa có thông tin.

## Nguyên tắc kiến trúc và triển khai

- Stack chưa được chọn. Không áp đặt AWS/Azure/Databricks/Snowflake, Python/dbt/
  Spark/orchestrator hay framework trước khi kiểm tra repo và yêu cầu hiện tại.
- Bắt đầu với một vertical slice nhỏ có thể kiểm chứng cả reporting và backfeed.
  Chỉ thêm dependency/service/abstraction khi có nhu cầu cụ thể.
- Hướng thiết kế đề xuất: tenant data plane riêng, Bronze raw → Silver canonical/
  history; daily Gold stars/marts cho BI và operational SQL read model riêng.
  Đây là proposal, không phải hạ tầng đã có hoặc quyết định cloud đã chốt.
- Dùng common code/contracts/IaC templates với tenant-specific configuration;
  không tạo các bản fork business logic theo hãng nếu cấu hình giải quyết được.
- Tách ingestion, normalization/DQ, domain evaluation, reporting và delivery về
  trách nhiệm. Domain logic không phụ thuộc trực tiếp vào engine/I/O khi có thể.
  Config boundaries rõ, type hints cho Python API mới, resource lifecycle đúng.

## Data contracts và correctness

- Chốt grain, business/surrogate keys, nullability, types, relationships và owner
  trước khi thêm table/product. Đồng bộ code, contracts, DDL, consumers và docs.
- Dữ liệu đích giữ tenant provenance; tenant context lấy từ trusted job/auth
  binding, không tin source tự khai tenant. Chặn sai tenant trước ghi dữ liệu.
- Giữ raw và derived riêng; phân biệt missing, null, empty, wrong type và malformed
  payload. Không tự sửa dữ liệu lỗi có chủ đích từ generator.
- Registry/source ID mappings phải explicit và duy nhất khi được yêu cầu.
  Không nối source IDs vì cùng prefix/số, không fallback tenant hoặc pilot khác.
- Phân biệt snapshot, insert/update, deactivation/tombstone và physical delete;
  giữ revision/history/lineage. Test corrections, late data và out-of-order replay.
- Event time, ingestion time, source update time, evaluation as-of, report date
  và SQL applied time có ý nghĩa riêng. Giữ raw timezone/offset và canonical UTC;
  employmentdate là date, không phải timestamp.
- Qualification assignment khác achievement. Preserve rule versions, evidence
  refs, missing/failed requirements và technical errors; lỗi kỹ thuật không trở
  thành business fail hoặc qualified mặc định. Không tự cấp certification.
- Tests phải dùng as-of/clock explicit. Tái lập dữ liệu incremental từ manifest,
  source checkpoints và effective generation config, không chỉ seed.
- Star facts giữ grain riêng; tránh fan-out khi join Flight, attempts, sections,
  items, roles và qualification evidence. SCD2 không overlap validity windows.

## Reporting và BI handoff

- Có hai report-facing contracts: learning status và qualification status.
  Chốt cutoff, deadline, timezone và late-source policy trước nghiệm thu daily SLA;
  cadence 1 lần/ngày không tự xác định những tham số đó.
- Learning report giữ expected learning targets kể cả khi thiếu evidence;
  enrollment/progress/exam/assessment statuses không bị gộp tùy tiện.
- Daily publication có coherent version, source cutoff/checkpoints, evaluation
  as-of, rule/mapping versions, completeness và freshness. Publish sau validation.
- Handoff typed tables/views, grain/keys/relationships, business measures,
  data dictionary, access contract và sample queries/expected results cho BI dev.
  Power BI refresh/display timing phối hợp riêng với BI team.

## Qualification backfeed

- Target là SQL Server được chỉ định; schema, app pilot mapping, enums, ownership,
  lifecycle/error semantics và transaction boundary phải kiểm chứng/chốt trước
  integration. Không lấy source DDL hay warehouse surrogate keys làm app contract.
- Reevaluate impacted keys khi evidence/mapping/assignment/rule đổi; thêm time
  triggers cho expiry/rolling window dù không có CDC. Không chỉ chạy theo lịch BI.
- Durable delivery, retry và sink idempotent; ack/checkpoint sau commit. Older
  per-key state không overwrite newer state, kể cả sau crash/backfill/reordering.
  Không suy rộng thành exactly-once/concurrent-writer guarantee khi chưa test.
- Không để stale last-good QUALIFIED bị hiểu là current hợp lệ sau error/revocation/
  inactive/removed assignment; dùng lifecycle/freshness contract đã chốt với app.
- Target outage giữ backlog, retry/reconciliation và cảnh báo theo tenant.
  Không tự ghi đè client edits khi chưa có write-authority/conflict policy.
- Đo source availability → detection → evaluation → delivery → SQL commit/read
  visibility, p50/p95/p99/max và queue/stale-key metrics. Ghi rõ phần lag không đo
  được; benchmark trước khi đề xuất numeric SLO.

## Isolation, governance và observability

- Isolation bao phủ raw/curated, graph, checkpoints, DQ/quarantine, temp/spill,
  logs chứa data, BI extracts/caches, exports và backups. Test negative access,
  overlapping IDs và routing/recovery/cleanup sai tenant.
- Shared control plane chỉ giữ metadata được phép; business data và custom
  policy contents giữ trong tenant boundary. RLS có thể hỗ trợ trong một hãng.
- Dùng secret references; không đọc/in `.env`, tokens, credentials hoặc URLs để
  khảo sát. Không commit/log secrets hay real PII; dùng identifiers giả/example.test.
- Có owner/steward, lineage, classification, retention và contract/version cho
  products. Phân biệt job success, DQ state, business status và delivery success.
- Logs có correlation IDs và safe context; metrics/alerts/runbooks riêng cho
  reporting deadline, source lag, evaluation errors và SQL delivery/backlog.

## Tests, CI/CD và IaC

- Tests cho thay đổi logic phải xác minh hành vi: contract/type/null boundaries,
  identity/isolation, DQ, mapping thresholds/anniversaries, qualification semantics,
  replay/corrections/delete, daily consistency và delivery ordering/recovery.
- Dùng fixtures nhỏ và local/fake/test environments theo stack; default tests
  không phụ thuộc production hoặc tự tạo cloud resources có phí.
- Dùng source raw inputs và independent assertions. Mockgen-derived normalization/
  evaluations/audit là validation oracle riêng, không là input làm platform outputs.
- Run focused checks trước; broader/integration checks theo phạm vi ảnh hưởng.
  Chỉ chạy commands được xác minh từ manifests/CI/README của repo; không giả định
  repo mới đã có pytest, make targets, Terraform hoặc deployment scripts.
- CI/CD version code/config/contracts/policies/IaC. Infra plan/schema impact phải
  review được; code rollback khác data recovery/backfill. Pin upstream generator
  commit/release/contract trong test provenance.
- Chỉ apply/deploy/ghi target được yêu cầu hoặc đã có authorization trong session;
  không tự migrate/drop/cleanup remote, đổi production settings hoặc tạo tài nguyên
  có phí ngoài phạm vi. Hoàn thành code/plan/tests review được trước bước phê duyệt
  thực sự cần thiết; không xin lại quyền cho việc đã được cho phép.

## Persistent project memory

- Memory chuẩn: `docs/ai-context/` số ít, gồm CURRENT_STATE, BUSINESS_RULES,
  ARCHITECTURE và HISTORY. Không tạo bộ song song dưới `docs/ai-contexts/`.
- Code/tests/contracts và yêu cầu được duyệt quyết định implementation. Markdown
  là context, không chứng minh runtime hay tests pass.
- Sau mỗi user turn, chỉ cập nhật memory nếu có thay đổi bền vững về business,
  contract/model, responsibilities hoặc architecture. Sửa định dạng/debug đơn
  thuần không tạo thêm quyết định memory.
- Khi có thay đổi, cập nhật BUSINESS_RULES và/hoặc ARCHITECTURE, CURRENT_STATE
  ngắn gọn; append đúng một entry HISTORY có ngày, rationale/status, relevant
  paths và validation thực tế. HISTORY append-only; chỉ search/tail phần cần.
- Dùng ACCEPTED, PROPOSED, IMPLEMENTED, SUPERSEDED và UNVERIFIED đúng nghĩa.
  Chỉ IMPLEMENTED khi có code trong repo này; chỉ pass khi tests/checks đã chạy.
  Không nhập lịch sử/test counts/deployment claims của mockgen thành thành tích
  của platform. Ghi provenance rõ nếu cần nhắc kết quả upstream.
- CURRENT_STATE dưới khoảng 120 dòng, không chép source/logs/secrets/transcripts.
  Ghi pending business decisions riêng, không biến assumptions thành policy.

## Cách làm việc và báo cáo

- Dùng `rg`, targeted reads và bounded output; không dump repo hoặc đọc lại files
  không đổi. Parallelize các reads/checks độc lập khi phù hợp; không tự mở thêm
  agents nếu chưa được yêu cầu.
- Với việc phức tạp, báo ngắn cách tiếp cận và cập nhật phát hiện/uncertainty.
  Tự giải quyết chi tiết triển khai thông thường trong phạm vi đã giao.
- Khi bàn giao: nêu outcome/paths, thay đổi vì sao, validation đã chạy và phần
  chưa kiểm chứng. Không báo DONE nếu chỉ có skeleton hoặc còn acceptance bắt buộc
  chưa đạt; phân biệt documentation/design với deployed functionality.
