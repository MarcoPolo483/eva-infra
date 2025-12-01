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

---

CI: guardrails smoke test (trigger) — 2025-12-01
CI: guardrails smoke test (trigger 2) — 2025-12-01T07:22ZCI: guardrails smoke test (auto) — 20251201-071901
CI: guardrails smoke test (auto) — 20251201-072052
CI: guardrails smoke test (auto) — 20251201-072459
