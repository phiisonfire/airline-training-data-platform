# Cleanup toàn bộ DevOps lab

Scope: resources do platform và bootstrap state quản lý, sau đó tài nguyên lab
được tạo ngoài Terraform. Các lệnh bên dưới XÓA dữ liệu thật khi operator chạy.
Runbook chưa được chạy trên AWS. Không bảo đảm zero bill: usage đã phát sinh vẫn
được tính và billing có độ trễ. Không tạo Organization/upgrade plan để cleanup.

## 1. Xác định deployment và dừng writers

Chạy từ root repo trong WSL, dùng profile quản trị đã login (ví dụ atdp-terraform).
Không dùng CI apply role: role đó cố ý không được xóa tenant data objects.

```bash
export AWS_PROFILE=atdp-terraform
aws sts get-caller-identity
umask 077
mkdir -p phi_local/cleanup
```

Xác minh Account/Arn trước mọi lệnh mutation. Ghi lại Region, deployment name,
pipeline name, bucket names, KMS key IDs, repository name và tài nguyên tự tạo.
Lưu bootstrap_contract khi backend còn truy cập được:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap output -json bootstrap_contract > phi_local/cleanup/bootstrap-contract.json
```

Trong CodePipeline Console: disable inbound transition vào Build; stop tất cả
executions đang chạy/queued và chờ CodeBuild builds dừng. Không approve executions.
Disable EventBridge Scheduler của deployment trong Console nếu platform đã deploy;
stop Step Functions executions, chờ Lambda invocations hoàn tất. Không push thêm
commits vào source trong cleanup. Nếu CloudTrail đã bật, stop logging trước khi
xóa audit bucket. Chỉ thao tác đúng deployment lab, không sửa resources dùng chung.

## 2. Chuẩn bị đúng config, state và destructive flags

Nếu CHỈ bootstrap đã apply và platform chưa có resources, bỏ qua phần platform.
Nếu partial apply, vẫn cleanup state của root tương ứng, không coi là chưa deploy.
Không xóa state, không state rm để che resources và không init backend rỗng mới.

- Bootstrap: giữ terraform.tfvars gốc và backend binding đúng deployment.
- Platform: dùng đúng deployment.auto.tfvars.json đã generate cho release được
  deploy và build/lambda.zip tương ứng. Nếu chạy từ CI, lấy BuildOutput của đúng
  execution về nơi private; không dùng config mẫu chứa REPLACE. Khôi phục inputs
  và ZIP trước khi plan nếu thiếu. Cần đủ inputs kể cả khi chỉ destroy.
- Init platform với bucket/key/region/KMS từ bootstrap_contract, key bắt đầu
  platform/, encrypt=true, use_lockfile=true như deployment gốc. Không init nhầm
  key bootstrap/. Dùng owner profile cho toàn bộ cleanup.

Ví dụ init platform (thay ALL_CAPS bằng binding thật):

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform init -reconfigure -backend-config=bucket=STATE_BUCKET -backend-config=key=platform/DEPLOYMENT/terraform.tfstate -backend-config=region=REGION -backend-config=kms_key_id=CONTROL_KMS_ARN -backend-config=encrypt=true -backend-config=use_lockfile=true
```

Kiểm kê và backup state vào thư mục private; KHÔNG in hoặc commit state:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap state list
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap state pull > phi_local/cleanup/bootstrap-before.tfstate
```

Nếu có platform resources:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform state list
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform state pull > phi_local/cleanup/platform-before.tfstate
```

Code lab hiện bỏ prevent_destroy; buckets force_destroy=true, secret recovery=0,
KMS deletion window=7. Với deployment cũ, phải normal plan/apply để ghi các flags
mới vào state TRƯỚC destroy. Đừng chạy destroy trực tiếp với force_destroy=false
trong state. Plan phải chỉ có thay đổi cleanup mong muốn; nếu có create/replace
hoặc thay đổi khác, xử lý drift/config mismatch trước, không apply mù.

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap plan -out=cleanup-settings.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap show cleanup-settings.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap apply cleanup-settings.tfplan
```

Nếu có platform, lặp lại ba lệnh trên với -chdir=infra/terraform/platform.
Normal apply có thể cập nhật pipeline/schedule: kiểm tra lại writers đã dừng sau
bước này. Không bật CloudTrail vốn chưa được tạo chỉ để cleanup.

## 3. Destroy platform trước

Chỉ khi platform state có resources:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform plan -destroy -out=destroy.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform show destroy.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform apply destroy.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/platform state list
```

State list phải không còn resources. Bucket data và mọi versions bị xóa vĩnh viễn,
secret bị yêu cầu xóa không recovery, Lambda/workflow/endpoints/logs/alarms/catalog
và roles do module tạo được xóa. KMS được schedule deletion, không xóa tức thì.
Nếu Athena báo workgroup không rỗng, xóa named queries/prepared statements của
đúng workgroup trong Console rồi re-plan. Nếu SG còn ENI, chờ Lambda ENI cleanup;
inspect dependencies, không xóa shared ENI/VPC. Nếu destroy lỗi giữa chừng, giữ
state, sửa nguyên nhân và tạo destroy plan mới. Không tiếp tục bootstrap khi còn
platform resources phụ thuộc control plane.

## 3b. Cleanup network một VPC (nếu đã deploy)

Sau platform: xóa SQL host/ENIs/storage tạo ngoài Terraform trong database/application subnets,
rồi destroy root infra/terraform/network bằng owner, backend key network/<deployment>/terraform.tfstate.
Xem [single-VPC cleanup](single-vpc-lab.md). Không xóa state bucket/bootstrap trước
network. Nếu còn source/platform ENIs, xử lý dependency trước, không state rm.

## 4. Đưa bootstrap state về local trước khi xóa state bucket

Nếu bootstrap vốn dùng local backend và chưa migrate S3, bỏ qua migration.
Nếu đang dùng S3 backend: backup đã làm ở trên, giữ local disk private/encrypted.
Thay nội dung file ignored infra/terraform/bootstrap/backend.tf thành:

```hcl
terraform {
  backend "local" {}
}
```

Chạy migration và xác nhận copy state khi Terraform hỏi:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap init -migrate-state
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap state list
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap state pull > phi_local/cleanup/bootstrap-local.tfstate
```

Không dùng -reconfigure thay -migrate-state ở bước này. Đối chiếu resource addresses
với bản trước migration; chỉ tiếp tục khi local backend chứa đúng resources.
Bucket remote còn các state snapshots/versions: force_destroy sẽ xóa chúng. Nếu
bucket này lưu deployment khác, DỪNG; cleanup các deployment đó riêng trước.

## 5. Destroy bootstrap

Dùng operator local, không chạy qua chính pipeline sắp bị xóa:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap plan -destroy -out=destroy.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap show destroy.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap apply destroy.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap state list
```

Kết quả phải không còn resources trong state. State/artifacts/audit buckets và
versions bị xóa. CI projects/pipeline/IAM/log groups bị xóa; control KMS chờ xóa.
Không chạy ci/initialize_state.py sau cleanup; nó sẽ cố ghi lại remote state.

## 6. Tài nguyên ngoài Terraform và kiểm chứng chi phí

Terraform không xóa tài nguyên được tạo ngoài hai states. Trong AWS Console,
kiểm tra TẤT CẢ Regions bạn từng dùng, xóa những resources lab do bạn sở hữu:

- CodeCommit repository: backup code cần giữ về local rồi delete repository nếu
  muốn xóa toàn bộ lab. Không xóa Git repository trên máy khi chưa giữ bản backup.
- SQL test instance/RDS/EC2, volumes, snapshots/backups, public IPv4/Elastic IP,
  NAT gateways, interface endpoints, buckets/log groups tạo tay, Athena results.
  VPC/subnets/routes mà repo chỉ tham chiếu KHÔNG bị Terraform xóa; chỉ xóa nếu
  dedicated lab, không có workloads khác. Kiểm tra tất cả lab deployments/states.
- KMS Console: xác minh từng lab key là PendingDeletion, lưu deletion date. AWS
  bắt buộc chờ tối thiểu 7 ngày; không thể xóa ngay bằng Terraform. Đừng cancel
  deletion nếu mục đích là kết thúc lab.
- Secrets Manager: xác minh secret lab đã được yêu cầu xóa; xóa là asynchronous.
- IAM user lab-admin không có phí theo user; có thể giữ cho cleanup verification.
  Nếu muốn xóa, thực hiện cuối cùng sau khi xử lý resources, access keys và login
  profile. Không tự xóa account root hoặc đóng AWS account bằng runbook này.

Trong Billing: kiểm tra credits, usage theo service/Region, và dữ liệu cập nhật
trong những ngày tiếp theo. Costs đã phát sinh không bị hoàn lại khi destroy.
State rỗng không chứng minh account không còn resources/charges; đối chiếu Console,
Resource Explorer/Tag Editor (nếu có) và billing, không chỉ dựa vào tag search.
Sau khi verification xong, xóa các bản state/plan chứa metadata nhạy cảm ở local
khi không còn cần phục hồi. Không restore state cũ rồi apply để kiểm tra cleanup.

## Tham chiếu

- [S3 force_destroy cần apply trước destroy](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/s3_bucket)
- [KMS deletion waiting period](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html)
