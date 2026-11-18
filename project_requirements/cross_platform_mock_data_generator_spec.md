# Cross-Platform Mock Data Generator Specification

## TMDS · LMS · ETR · Flight API · QMS

**Audience:** Coding agent\
**Goal:** Implement a reproducible, configurable mock-data generator for
a pilot training and qualification platform. Generate linked data across
SQL Server, an external Flight API, and a graph database; support
initial loads, incremental CRUD-like changes, controlled DQ injection,
normalization, and end-to-end qualification scenarios.

------------------------------------------------------------------------

## 1. Core implementation principles

1.  Use actual supplied source schemas wherever available. Do not invent
    physical LMS columns or relationships before inspecting its DDL.
2.  Treat TMDS, LMS, ETR, Flight API, and QMS as separate source/domain
    boundaries.
3.  Preserve raw source values and payloads. Normalization must produce
    derived canonical values, never destroy raw evidence.
4.  Generate stable cross-system pilot identity through a canonical ID
    registry. Source IDs are not assumed to be equal.
5.  Keep clean baseline generation separate from opt-in DQ injection.
6.  Make runs deterministic using a seed, run ID, config hash, and
    scenario manifest.
7.  Make incremental operations idempotent and auditable.
8.  Keep qualification business semantics independent from the
    processing engine.
9.  Never turn a technical parsing or evaluation error into a business
    qualification failure.

## 2. Systems and known schema

  -----------------------------------------------------------------------
  System                  Technology              Responsibility
  ----------------------- ----------------------- -----------------------
  TMDS                    SQL Server              Pilot identity,
                                                  organization, location,
                                                  manager scope

  LMS                     SQL Server              Courses, classes,
                                                  lessons, enrollments,
                                                  progress, exams,
                                                  results, attendance

  ETR                     SQL Server              Electronic/simulator
                                                  training, assessments,
                                                  assessment elements,
                                                  attempts/sections,
                                                  result JSON

  Flight API              External API            Actual flight records:
                                                  pilot ID,
                                                  departure/landing
                                                  locations, departure
                                                  datetime, flight
                                                  duration

  QMS                     Graph database          Qualifications,
                                                  certifications,
                                                  requirements,
                                                  dependencies, evidence
                                                  mappings, qualification
                                                  outcomes
  -----------------------------------------------------------------------

### 2.1 Known SQL Server tables

**TMDS** - `tmds_users` (`location_id`, `organization_id`, `user_type`
are known fields) - `tmds_location` - `tmds_organization` -
`tmds_manager_scope`

**ETR** - `etr_users` - `etr_assessments` - `etr_assessment_elements`
(includes `result_json` containing section/result information) -
`flight_api_responses` (inspect actual DDL and semantics before using)

Known relationships: - `etr_users.tmds_user_id` →
`tmds_users.tmds_user_id` - `etr_assessments.etr_user_id` →
`etr_users.etr_user_id` - `etr_assessment_elements.assessment_id` →
`etr_assessments.assessment_id` - `etr_assessment_elements.etr_user_id`
→ `etr_users.etr_user_id` - `flight_api_responses.assessment_element_id`
→ `etr_assessment_elements.assessment_element_id` when applicable.

**Important:** Actual flight records are independent operational
evidence. Do not require every flight to have an `assessment_element_id`
or an ETR parent.

### 2.2 LMS logical entities

Inspect the actual LMS schema and map its physical tables to these
logical entities: - Courses, classes, lessons, course-lesson
association - Enrollments and lesson progress - Exams, exam attempts and
results - Attendance

The names above are logical suggestions, not assumed physical table
names. Implement a configurable mapping layer.

### 2.3 Flight API known contract

The API contains actual flight information: - Pilot ID - Departure
location - Landing / arrival location - Flight duration - Departure date
and time

Exact JSON property names, stable flight record ID, timezone metadata,
duration unit metadata, arrival datetime, aircraft type, and update
semantics are not yet confirmed. Do not assume they exist. Support
optional generator-enriched fields only when clearly marked as mock
extensions.

------------------------------------------------------------------------

## 3. Suggested project structure

``` text
mock-data-generator/
  pyproject.toml
  README.md
  configs/
    base.yaml
    local.yaml
    cloud.example.yaml
    generation/
      pilots.yaml
      datetime.yaml
      flight_duration.yaml
      dq_profiles.yaml
      scenarios.yaml
    mappings/
      tmds.yaml
      etr.yaml
      lms.example.yaml
      flight_api.yaml
      qms.yaml
  src/mockgen/
    cli.py
    config/
    core/                 # IDs, seed, run context, contracts, registry
    adapters/
      sqlserver/
      graph/
      flight_api/
      storage/
    generators/
      tmds/
      lms/
      etr/
      flight/
      qms/
    normalization/
      datetime_parser.py
      duration_parser.py
      location_normalizer.py
    dq/                   # catalog, injector, validators, quarantine
    scenarios/
    orchestration/
    audit/
  tests/
    unit/
    contract/
    integration/
    scenario/
    normalization/
  docs/
```

Recommended stack: Python 3.11+, SQLAlchemy, Pydantic, Faker, Typer,
pytest, httpx. Polars/Pandas may be used for local batch work. Keep
cloud and graph vendor dependencies behind adapters.

------------------------------------------------------------------------

## 4. Configuration and connections

Inject credentials at runtime via environment variables or a secret
manager. Never commit secrets.

Illustrative configuration:

``` yaml
environment: local
seed: 20261111

connections:
  tmds_sqlserver:
    url_env: TMDS_DATABASE_URL
  lms_sqlserver:
    url_env: LMS_DATABASE_URL
  etr_sqlserver:
    url_env: ETR_DATABASE_URL
  qms_graph:
    adapter: neo4j
    uri_env: QMS_GRAPH_URI
    username_env: QMS_GRAPH_USERNAME
    password_env: QMS_GRAPH_PASSWORD
  flight_api:
    base_url_env: FLIGHT_API_BASE_URL
    token_env: FLIGHT_API_TOKEN
    mode: mock

generation:
  pilots:
    count: 1000
    id_prefix: PILOT
  datetime:
    canonical_timezone: UTC
  flight_duration:
    canonical_unit: seconds

runtime:
  batch_size: 500
  dry_run: false
```

Support local SQL Server, Azure SQL, SQL Server on cloud VMs/on-prem,
and graph adapters such as Neo4j, Neptune, or Cosmos Gremlin where
supported. Graph capabilities differ; do not assume identical
constraints, transactions, or query syntax.

------------------------------------------------------------------------

## 5. Canonical pilot identity

Create a durable registry mapping one canonical pilot to source-specific
IDs.

  Canonical ID     TMDS ID     ETR ID      LMS ID      Flight API pilot ID
  ---------------- ----------- ----------- ----------- ---------------------
  `PILOT-000001`   source ID   source ID   source ID   source ID

Requirements: - Stable canonical `pilot_id` across repeated and
incremental runs. - Source IDs may differ across systems. - Support
missing, duplicate, stale, and conflicting mappings as explicit DQ
cases. - TMDS organization/location/manager relationships must be
generated consistently. - QMS and qualification results reference
canonical identity, not arbitrary source IDs.

Persist this registry in generator metadata storage or durable run
artifacts.

------------------------------------------------------------------------

## 6. Lifecycle and CLI

Implement:

``` bash
mockgen validate-config
mockgen validate-connections
mockgen initial --profile clean
mockgen incremental --scenario course_completed
mockgen incremental --scenario flight_record_corrected
mockgen dq-inject --scenario mixed_datetime_formats
mockgen dq-inject --scenario ambiguous_flight_duration
mockgen qms-change --scenario qualification_rule_updated
mockgen validate-data --run-id <run_id>
mockgen history
mockgen cleanup --run-id <run_id> --dry-run
```

### Initial load order

1.  TMDS: organizations, locations, pilots/users, manager scopes.
2.  LMS: courses/classes/lessons, enrollments, progress, exams/results,
    attendance.
3.  ETR: users, assessments, assessment elements, attempts/sections and
    result payloads.
4.  Flight API: pilot mappings and actual flight records.
5.  QMS: qualification/certification/requirement graph and evidence
    mappings.

Respect actual FK constraints and use stable IDs.

### Incremental changes

Support create/update/delete or deactivate where the source supports
it: - Pilot created or moved to another organization/location - LMS
enrollment, lesson progress, attendance, exam result changed - ETR
assessment/attempt/section result added or corrected - Actual flight
added, corrected, replayed, or delivered late - Pilot mapping added,
removed, or corrupted - QMS qualification rule/dependency updated

Replay must be idempotent unless a duplicate defect is deliberately
injected.

### Run manifest

Record `run_id`, seed, generator version, config hash, timestamps,
status, target systems/tables, scenario names, DQ issue IDs, affected
canonical pilot IDs, created/updated/deleted counts, validation results,
and errors. Do not include credentials. Keep append-only run history.

------------------------------------------------------------------------

## 7. Datetime variation and normalization

Datetime format variation is a mandatory feature. Generate raw values in
configurable proportions from: - ISO UTC: `2026-11-11T08:30:00Z` - ISO
with offset: `2026-11-11T15:30:00+07:00` - ISO without timezone:
`2026-11-11T15:30:00` - SQL style: `2026-11-11 15:30:00` - US locale:
`11/11/2026 03:30 PM` - EU locale: `11.11.2026 15:30` - Date only:
`2026-11-11` - Unix epoch seconds or milliseconds - Excel serial date
(only with known origin) - Ambiguous locale date: `11/12/2026`

A mixture of supported, unambiguous formats is normal source variation,
not automatically a DQ failure.

### Logical raw and lineage fields

Use these where the physical source permits them; otherwise preserve
them in raw payloads, raw landing, or generator sidecar metadata:

  Field                 Purpose
  --------------------- --------------------------------------------
  `*_raw`               Exact original source value
  `*_format`            Source/generator format identifier
  `*_timezone`          Source timezone or explicit unknown marker
  `*_at`                Canonical normalized timestamp
  `source_created_at`   Source creation time
  `source_updated_at`   Source update time
  `event_at`            Business event time
  `ingested_at`         Platform ingestion time

Canonical timestamps should be timezone-aware UTC. Preserve raw value
and source timezone. Do not silently assign UTC to naive timestamps
unless a documented source-specific policy requires it.

### Datetime DQ scenarios

  -----------------------------------------------------------------------
  ID                      Scenario                Expected behavior
  ----------------------- ----------------------- -----------------------
  DQ-DT-001               Mixed supported formats Parse; retain format
                                                  lineage

  DQ-DT-002               Ambiguous locale date   Quarantine/flag; never
                                                  guess

  DQ-DT-003               Missing timezone        Apply explicit source
                                                  policy or quarantine

  DQ-DT-004               Invalid timezone offset Quarantine with error
                                                  code

  DQ-DT-005               Epoch seconds mixed     Detect by
                          with milliseconds       contract/range; no
                                                  blind guessing

  DQ-DT-006               Invalid datetime string Quarantine

  DQ-DT-007               Future                  Business-rule
                          completion/departure    warning/error
                          date                    

  DQ-DT-008               End before start        Temporal integrity
                                                  error

  DQ-DT-009               DST                     Require explicit policy
                          ambiguous/nonexistent   or quarantine
                          local time              

  DQ-DT-010               Date-only used as       Preserve date
                          timestamp               semantics; do not
                                                  invent time

  DQ-DT-011               Excel serial without    Quarantine
                          known origin            

  DQ-DT-012               Precision               Flag if
                          mismatch/truncation     business-significant

  DQ-DT-013               Late-arriving event     Keep event time
                                                  separate from ingestion
                                                  time

  DQ-DT-014               Update timestamp before Flag source
                          create timestamp        inconsistency

  DQ-DT-015               Conflicting timestamps  Apply source-of-truth
                          across systems          policy and retain
                                                  conflict
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 8. Flight API records and duration normalization

### 8.1 Logical raw API payload

Illustrative only; map the real API property names through
configuration:

``` json
{
  "flight_record_id": "FLT-00000001",
  "pilot_id": "EXT-PILOT-000123",
  "departure_location": "SGN",
  "landing_location": "DAD",
  "departure_datetime": "2026-11-11T08:30:00+07:00",
  "flight_duration": "15m:30s"
}
```

The real API is known to provide pilot ID, departure location, landing
location, departure datetime, and flight duration. A stable
`flight_record_id` is not yet confirmed; if absent, create a
deterministic synthetic source reference and document its business key.
Capture the raw API response for audit and parser regression tests.

Treat this as a first-class actual-flight domain. Do not make an ETR
assessment link mandatory. If the existing `flight_api_responses` table
is used, inspect its schema and retain its current constraints/meaning.

### 8.2 Duration formats to generate

-   `15m:30s`
-   `15.5min`
-   `930 seconds`
-   `00:15:30`
-   `0.258333 hours`
-   `PT15M30S` (ISO 8601 duration)
-   `15,5 min` (locale decimal)
-   `15 min 30 sec`
-   `15.5` (unit missing; ambiguous)
-   `15:30` (ambiguous unless source contract defines it)

### 8.3 Canonical duration

Store valid duration as **integer `duration_seconds`**. Derived values
are `duration_minutes = seconds / 60.0` and
`duration_hours = seconds / 3600.0`. Do not use floating point as the
canonical representation or discard meaningful seconds.

Recommended normalized logical fields:

  -----------------------------------------------------------------------
  Field                               Meaning
  ----------------------------------- -----------------------------------
  `flight_record_id`                  Stable source or synthetic record
                                      identifier

  `pilot_id`                          Canonical pilot ID after mapping

  `departure_location`                Raw or mapped departure location

  `landing_location`                  Raw or mapped landing location

  `departure_datetime_raw`            Exact API value

  `departure_datetime_utc`            Parsed UTC datetime

  `flight_duration_raw`               Exact API value

  `duration_format`                   Known parser format, if available

  `duration_seconds`                  Integer; null if invalid/ambiguous

  `duration_parse_status`             `PARSED`, `AMBIGUOUS`, `INVALID`,
                                      `MISSING`

  `normalization_error_code`          Structured failure reason

  `source_reference`                  API record reference

  `ingested_at`                       Ingestion timestamp
  -----------------------------------------------------------------------

Use a raw response store/table and a normalized logical entity such as
`flight_records`; physical names may vary.

### 8.4 Parser rules

-   Use a parser registry with explicit patterns and unit definitions.
-   Prefer source/API version contract or metadata to determine format.
-   Never infer a unit from bare `15.5`.
-   Never assume `15:30` means minutes:seconds unless the contract says
    so.
-   Parse decimal comma only when locale is known/unambiguous.
-   Validate component ranges. For `15m:90s`, normalize overflow only if
    an explicit policy allows it; otherwise reject.
-   Record parser/normalization version.
-   Unparsed or quarantined records must not contribute to qualification
    totals.

### 8.5 Flight duration DQ catalog

  -----------------------------------------------------------------------
  ID                      Scenario                Expected behavior
  ----------------------- ----------------------- -----------------------
  DQ-FLT-001              Mixed supported formats Equivalent values
                                                  normalize to identical
                                                  seconds

  DQ-FLT-002              Unit missing (`15.5`)   Ambiguous; no guessing

  DQ-FLT-003              Ambiguous colon         Resolve only from
                          (`15:30`)               contract; else
                                                  quarantine

  DQ-FLT-004              Negative duration       Invalid

  DQ-FLT-005              Unknown format          Quarantine with parser
                                                  error

  DQ-FLT-006              Decimal comma           Parse only with known
                                                  locale

  DQ-FLT-007              Seconds overflow        Explicit
                          (`15m:90s`)             normalize-or-reject
                                                  policy

  DQ-FLT-008              Implausibly long        Configurable
                          duration                plausibility rule

  DQ-FLT-009              Zero duration           Flag according to
                                                  business policy

  DQ-FLT-010              Conflicting duration    Preserve both;
                          fields                  quarantine or
                                                  documented precedence

  DQ-FLT-011              Unit metadata conflicts Flag conflict
                          with text               

  DQ-FLT-012              Duplicate flight record Detect via source
                                                  ID/business key

  DQ-FLT-013              Corrected duration      Keep history and
                          after ingestion         trigger re-evaluation

  DQ-FLT-014              Pilot ID cannot be      Retain raw record;
                          mapped                  exclude from pilot
                                                  totals

  DQ-FLT-015              Departure datetime      Quarantine temporal
                          invalid                 evidence

  DQ-FLT-016              Departure/landing       Completeness issue
                          location missing        

  DQ-FLT-017              Repeated API delivery   Idempotent upsert

  DQ-FLT-018              Parser version changes  Record version;
                          result                  controlled reprocessing
  -----------------------------------------------------------------------

Baseline Flight API records represent **actual flights**. Do not infer
simulator time from this API. Simulator evidence should come from ETR or
another simulator source. Do not combine actual and simulator hours
unless an explicit QMS requirement permits it.

Potential QMS requirements include minimum total actual flight hours and
minimum actual flight hours in a rolling period. Only use additional
dimensions such as aircraft category if the source actually supplies
trustworthy data.

------------------------------------------------------------------------

## 9. QMS graph and qualification semantics

Use a DAG-capable model because
qualifications/certifications/requirements may be reused by multiple
parents.

Suggested node labels: - `Qualification` - `Certification` -
`Requirement` - `RequirementGroup` - Optional `Pilot`, `Evidence`

Suggested edges: - `CONTAINS` - `REQUIRES` - `DEPENDS_ON` -
`HAS_CERTIFICATION` - `SATISFIED_BY` - `HAS_EVIDENCE`

Requirements may depend on LMS course/exam evidence, ETR
assessment/section results, actual flight evidence, certification
validity, manual review, or evidence freshness. Support AND/OR groups,
effective dates, versions, and reusable nodes. Validate cycles in clean
baseline.

Qualification statuses: - `QUALIFIED` - `NOT_QUALIFIED` -
`PENDING_EVIDENCE` - `PENDING_REVIEW` - `EXPIRED` - `REVOKED` -
`EVALUATION_ERROR`

A valid failed assessment may mean `NOT_QUALIFIED`; missing evidence may
mean `PENDING_EVIDENCE`; parsing, data-contract, graph, or evaluator
failures must remain technical `EVALUATION_ERROR`.

Persist evaluation history: pilot/qualification IDs, rule version, input
snapshot/version, timestamp, status, satisfied/failed requirements,
missing evidence, evidence references, and technical error details.

------------------------------------------------------------------------

## 10. DQ injection framework

DQ injection is opt-in and configuration-driven. Every mutation must be
traceable.

Record per issue: - `dq_issue_id`, scenario ID, run ID - Source system,
entity, record ID, field/relationship - Issue type and severity (`INFO`,
`WARNING`, `ERROR`, `CRITICAL`) - Injected value and expected value
where appropriate - Expected detection layer and validation outcome -
Reversibility and cleanup/correction instructions

Reusable DQ categories: 1. Identity and mapping 2. Referential integrity
3. Missing/incomplete data 4. Duplicate records and duplicate delivery
5. Invalid enum/status 6. Datetime format/timezone/precision/temporal
defects 7. Flight duration format/unit/semantic defects 8. ETR JSON
parsing/schema defects 9. Cross-system inconsistency 10.
Late/out-of-order updates 11. QMS graph cycles/dangling edges/invalid
dependencies 12. Evidence and qualification evaluation defects

Profiles: - `clean`: no intentional defects - `low`: small number of
warnings - `moderate`: warnings and errors - `high`: dense defects for
resilience tests - `targeted`: only selected scenarios

Never randomly corrupt records without recording the mutation.

------------------------------------------------------------------------

## 11. End-to-end scenario catalog

  ------------------------------------------------------------------------------------
  Scenario                           Mutation                  Expected behavior
  ---------------------------------- ------------------------- -----------------------
  `clean_baseline`                   Generate linked data      All supported data
                                     across all systems        validates and links

  `pilot_created`                    Add pilot and source      New canonical identity
                                     identities                resolves

  `pilot_mapping_missing`            Omit/corrupt source       Evidence is not
                                     mapping                   attributed to another
                                                               pilot

  `course_completed`                 Update LMS                Re-evaluate relevant
                                     completion/exam evidence  requirements

  `assessment_passed`                Add valid ETR pass        Re-evaluate relevant
                                                               requirements

  `assessment_failed`                Add valid failed ETR      Requirement remains
                                     result                    unsatisfied

  `flight_record_added`              Add actual flight         Parse duration and map
                                                               pilot

  `flight_record_corrected`          Correct                   Update evidence and
                                     duration/departure        re-evaluate
                                     datetime                  

  `mixed_datetime_formats`           Mix supported datetime    Parse with lineage
                                     formats                   

  `ambiguous_datetime`               Inject ambiguous date     Quarantine; no guessing

  `mixed_flight_duration_formats`    Mix supported duration    Equivalent values yield
                                     formats                   equal seconds

  `ambiguous_flight_duration`        Inject bare               Quarantine; exclude
                                     numeric/ambiguous colon   from totals

  `duplicate_flight_delivery`        Replay same API response  Idempotent ingestion

  `late_arriving_flight`             Deliver old event after   Preserve event and
                                     newer event               ingestion times

  `cross_system_pilot_conflict`      Conflicting pilot         Apply source-of-truth
                                     attributes                policy

  `qms_rule_updated`                 Change                    Re-evaluate affected
                                     rule/version/dependency   pilots

  `qms_graph_cycle`                  Add dependency cycle      Reject or flag graph
                                                               change

  `qualification_pending_evidence`   Remove required evidence  Pending, not technical
                                                               failure

  `qualification_evaluation_error`   Malformed graph/input     Technical error, not
                                                               `NOT_QUALIFIED`
  ------------------------------------------------------------------------------------

Each scenario must define preconditions, affected records, mutation
steps, expected raw/normalized state, expected DQ issue, expected
qualification outcome, and cleanup/compensation.

------------------------------------------------------------------------

## 12. Validation and testing

### Validation layers

**Source:** required fields, schema compatibility, keys, types, enums.\
**Normalization:** tests for every datetime and duration format,
timezone/DST, equivalent duration conversion, and ambiguity rejection.\
**Cross-system:** every mapping resolves to one canonical pilot; no
evidence is attributed to the wrong pilot; Flight API remains
independent of ETR unless explicitly linked.\
**QMS:** graph constraints, evidence mapping resolution,
version/snapshot history, and separation of technical/business status.

### Mandatory parser tests

-   `15m:30s` → 930 seconds
-   `15.5min` → 930 seconds
-   `930 seconds` → 930 seconds
-   `00:15:30` → 930 seconds only when contract defines HH:MM:SS
-   `PT15M30S` → 930 seconds
-   `15.5` → ambiguous without unit metadata
-   `15:30` → ambiguous without format contract
-   `15,5 min` → parse only with known locale
-   Negative/malformed values → invalid

Datetime tests must include supported formats, ambiguous locale dates,
missing/invalid timezone, epoch seconds vs milliseconds, DST
overlap/gap, invalid strings, and date-only semantics.

Also test idempotent replay, incremental-vs-full rebuild parity,
cross-system links, cleanup safety, and parser-version regression.

------------------------------------------------------------------------

## 13. Operational requirements

-   Use transactions and batch upserts where supported.
-   Keep generator metadata separate from business source tables.
-   Cleanup only records created by the selected run; honor FK
    constraints.
-   Provide dry-run mode.
-   Use structured logs; do not log secrets.
-   Configure batch size, retries, and timeouts.
-   Distinguish transient API/connection errors from permanent
    data-quality errors.
-   Provide a deterministic mock Flight API with pagination and optional
    duplicate/late-arrival behavior.
-   Document whether every field is known, inferred, optional, or
    generator-enriched.
-   Do not assume all graph stores share capabilities.

## 14. Definition of done

1.  Connects to configured TMDS/LMS/ETR/QMS targets and Flight API mock
    without secrets in source control.
2.  Generates clean baseline data with stable cross-system pilot
    identity.
3.  Supports repeatable incremental create/update/delete or deactivation
    scenarios.
4.  Injects targeted, traceable DQ defects.
5.  Generates mixed datetime formats and correctly handles
    timezone/ambiguity.
6.  Generates actual-flight records with mixed duration formats; valid
    values normalize to integer seconds.
7.  Ambiguous datetime/duration values are flagged or quarantined, never
    guessed.
8.  Invalid/unmapped flight records are excluded from qualification
    totals.
9.  Generates and validates QMS graph/evidence mappings.
10. Separates business qualification outcomes from technical evaluation
    errors.
11. Produces reproducible run manifests and audit history.
12. Tests parsers, idempotency, cross-system relationships, and
    end-to-end scenarios.

------------------------------------------------------------------------

## 15. Integration details the coding agent must inspect

Before physical implementation, inspect and document: 1. Actual LMS DDL,
PKs, FKs, and status semantics. 2. QMS graph product, labels,
relationship types, constraints, and query interface. 3. Flight API
OpenAPI/spec or sanitized sample payloads: - Exact property names -
Whether duration unit/format metadata exists - Whether departure
datetime contains timezone/offset - Whether a stable flight record ID
exists - Pagination, corrections/updates, and deletion/tombstone
behavior 4. Existing ETR `flight_api_responses` DDL and whether it
stores raw API responses, assessment-linked simulator evidence, or both.
5. ETR `result_json` structure and assessment/section result semantics.
6. Source-of-truth policies for pilot identity, locations, and
timestamps.

If API metadata is absent, use a parser registry keyed by source/API
version and quarantine ambiguous values. Do not infer missing semantics
from the value alone.

## 16. Recommended implementation order

1.  Inspect schemas and create physical-to-logical mappings.
2.  Implement configuration, connection adapters, run context,
    deterministic IDs, and manifest.
3.  Implement clean TMDS generation and canonical pilot registry.
4.  Implement LMS and ETR generators using verified schemas.
5.  Implement Flight API mock/client, raw payload capture, datetime
    parser, and duration parser.
6.  Implement QMS graph adapter, graph generation, and evidence
    mappings.
7.  Pass clean-baseline validation and end-to-end tests.
8.  Add DQ registry and targeted injectors.
9.  Add incremental scenarios, idempotency, replay, and cleanup.
10. Add sample configs, local development setup, and runbooks.

**Priority:** Build a correct and auditable clean baseline first. Add
controlled DQ injection only after data contracts and cross-system
relationships pass tests.
