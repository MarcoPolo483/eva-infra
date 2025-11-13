# EVA Infra (Terraform)

Baseline Terraform skeleton for EVA 2.0 Azure landing zone.

## Structure
- modules/: reusable infra modules
- env/dev/: example environment composition
- .github/workflows/: CI for format/validate/plan

## Next
- Configure remote state in env/dev/backend.tf (Azure Storage) or run `terraform init -backend=false`
- Add variables to env/dev/terraform.tfvars (e.g., name_prefix, location)
- Run CI plan; validate private endpoints and baseline resources