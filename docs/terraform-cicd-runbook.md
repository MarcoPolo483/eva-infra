# Terraform CI/CD Pipeline Runbook

This document describes the CI/CD pipeline for EVA 2.0 infrastructure automation using GitHub Actions.

## Overview

The `terraform-ci.yml` workflow automates Terraform operations across environments:

- **Pull Request**: Format check, validate, plan (with PR comment)
- **Push to main**: Auto-apply to dev environment
- **Manual Dispatch**: Apply to any environment (dev/stg/prd) with approval

## Workflow Triggers

### Automatic Triggers

```yaml
# On PR to main (plan only)
pull_request:
  branches: [main]
  paths:
    - 'env/**'
    - 'modules/**'
    - '.github/workflows/terraform-ci.yml'

# On push to main (auto-apply to dev)
push:
  branches: [main]
  paths:
    - 'env/**'
    - 'modules/**'
```

### Manual Trigger

```yaml
# Workflow dispatch with environment selection
workflow_dispatch:
  inputs:
    environment:
      description: 'Environment to deploy (dev, stg, prd)'
      required: true
      default: 'dev'
```

## Jobs

### Job 1: `terraform-plan`

Runs on pull requests only.

**Steps**:
1. Checkout code
2. Setup Terraform 1.9.0
3. Azure Login via OIDC
4. `terraform fmt -check -recursive`
5. `terraform -chdir=env/dev init`
6. `terraform -chdir=env/dev validate`
7. `terraform -chdir=env/dev plan -out=tfplan`
8. Upload plan artifact (7-day retention)
9. Comment PR with plan output

**Outputs**:
- PR comment with format check and plan results
- Plan artifact for review

### Job 2: `terraform-apply`

Runs on push to main or manual dispatch.

**Steps**:
1. Checkout code
2. Setup Terraform 1.9.0
3. Azure Login via OIDC
4. `terraform -chdir=env/{env} init`
5. `terraform -chdir=env/{env} plan -out=tfplan`
6. `terraform -chdir=env/{env} apply -auto-approve tfplan`
7. Notify success/failure

**Environment Protection**:
- Dev: Auto-apply on push to main
- Stg/Prd: Require manual approval (GitHub environment protection rules)

## Prerequisites

### Azure OIDC Setup

Configure federated credentials for GitHub Actions:

```bash
# Create Azure AD App Registration
az ad app create --display-name "eva-infra-github-actions"

# Create service principal
az ad sp create --id <app-id>

# Assign Contributor role to subscription
az role assignment create \
  --assignee <app-id> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>

# Add federated credential for main branch
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "eva-infra-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:MarcoPolo483/eva-infra:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Add federated credential for pull requests
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "eva-infra-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:MarcoPolo483/eva-infra:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### GitHub Secrets

Configure in repository settings → Secrets and variables → Actions:

| Secret | Value | Description |
|--------|-------|-------------|
| `AZURE_CLIENT_ID` | `<app-id>` | Azure AD App Registration client ID |
| `AZURE_TENANT_ID` | `<tenant-id>` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `<subscription-id>` | Azure subscription ID |

### GitHub Environment Protection

Configure in repository settings → Environments:

**dev**:
- No protection rules (auto-apply)

**stg**:
- Required reviewers: 1 (platform team member)
- Wait timer: 0 minutes

**prd**:
- Required reviewers: 2 (platform team lead + security)
- Wait timer: 30 minutes
- Restrict to protected branches: main only

## Usage

### Development Workflow

1. Create feature branch:
   ```bash
   git checkout -b feat/add-cosmos-module
   ```

2. Make changes to Terraform code:
   ```bash
   # Edit modules or env configs
   vim modules/cosmos-db/main.tf
   ```

3. Push and create PR:
   ```bash
   git add .
   git commit -m "Add Cosmos DB module"
   git push origin feat/add-cosmos-module
   ```

4. Review plan in PR comment:
   - GitHub Actions posts plan output
   - Verify changes match intent
   - Check for unexpected resource deletions

5. Merge PR after approval:
   - Auto-applies to dev environment
   - Monitor workflow run for errors

### Deploying to Staging/Production

1. Navigate to Actions tab in GitHub
2. Select "Terraform CI/CD" workflow
3. Click "Run workflow"
4. Select environment: stg or prd
5. Confirm and run
6. Approve deployment when prompted (environment protection)
7. Monitor apply job for completion

## Troubleshooting

### Error: OIDC Authentication Failed

**Symptom**: `Error: login failed with Error: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL`

**Fix**:
1. Verify federated credential subject matches repository
2. Check `permissions.id-token: write` in workflow
3. Confirm AZURE_CLIENT_ID/TENANT_ID/SUBSCRIPTION_ID secrets

### Error: State Lock Conflict

**Symptom**: `Error acquiring the state lock: ConditionalCheckFailedException`

**Fix**:
```bash
# Force unlock (use with caution)
terraform -chdir=env/dev force-unlock <lock-id>

# Or wait for lease expiration (20 minutes)
```

### Error: Provider Version Mismatch

**Symptom**: `Error: Failed to query available provider packages`

**Fix**:
```bash
# Update provider version in modules/*/main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Reinitialize
terraform -chdir=env/dev init -upgrade
```

### Error: Resource Quota Exceeded

**Symptom**: `Error: creating/updating Resource: Code="QuotaExceeded"`

**Fix**:
1. Check quota limits:
   ```bash
   az vm list-usage --location canadacentral -o table
   ```
2. Request quota increase via Azure Portal
3. Or adjust resource configuration (smaller SKUs)

### Error: Missing RBAC Permissions

**Symptom**: `Error: authorization failed: Status=403 Code="AuthorizationFailed"`

**Fix**:
```bash
# Grant required role to service principal
az role assignment create \
  --assignee <app-id> \
  --role "Key Vault Administrator" \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-eva-dev-net
```

## Notifications (Future Enhancement)

To enable Slack/Teams notifications:

**Slack**:
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Terraform apply ${{ job.status }} for ${{ github.event.inputs.environment || 'dev' }}"
      }
```

**Microsoft Teams**:
```yaml
- name: Notify Teams
  uses: jdcargile/ms-teams-notification@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    webhook-uri: ${{ secrets.TEAMS_WEBHOOK_URI }}
    notification-summary: "Terraform apply ${{ job.status }}"
```

## Best Practices

1. **Always review plan output**: Never merge without checking plan comment
2. **Small, incremental changes**: Avoid large PRs with many resource changes
3. **Test in dev first**: Validate changes in dev before promoting to stg/prd
4. **Monitor apply jobs**: Watch for partial failures or drift
5. **Document breaking changes**: Add comments in PR for destructive operations
6. **Use `-target` sparingly**: Avoid targeting specific resources unless necessary
7. **Keep modules isolated**: Changes to one module shouldn't affect others
8. **Rotate credentials regularly**: Update OIDC federated credentials annually

## References

- [GitHub Actions OIDC with Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [EVA Terraform State Management](../terraform-state-management.md)
- [EVA Naming Conventions](../naming-conventions.md)
