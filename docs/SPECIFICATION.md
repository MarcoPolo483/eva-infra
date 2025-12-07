# EVA Infrastructure as Code (eva-infra)

**Comprehensive Specification for Autonomous Implementation**

---

## 1. Vision & Business Value

### What This Service Delivers

EVA-Infra provides **Infrastructure as Code (IaC)** for the entire EVA Suite using Terraform on Azure:

- **Azure Resources**: Cosmos DB, Azure AI Search, Azure OpenAI, Blob Storage, Redis Cache, Key Vault
- **Networking**: VNet, subnets, private endpoints, NSGs, DDoS protection (optional)
- **Security**: Managed identities, Key Vault secrets, RBAC roles, private networking
- **Monitoring**: Application Insights, Log Analytics workspace, alerts, cost tracking
- **Environments**: Dev, Test, Prod (shared infrastructure model with logical isolation)
- **CI/CD**: GitHub Actions workflows for plan, apply, destroy with approval gates

### Success Metrics

- **Deployment Success Rate**: 100% (all resources provisioned without manual intervention)
- **Deployment Time**: < 30 minutes for full environment (dev/test/prod)
- **Cost Control**: $36/month baseline (vs $99 for separate environments)
- **Security Compliance**: 100% resources with private endpoints (no public access in prod)
- **Reproducibility**: `terraform destroy` + `terraform apply` creates identical environment

### Business Impact

- **Offline Resilience**: Marco's laptop can run everything locally (LocalStack for Azure emulation)
- **Multi-Tenant Isolation**: Complete data isolation via Cosmos DB containers + resource groups
- **Cost Transparency**: Azure Cost Management tags track spending per service
- **Rapid Provisioning**: New client environment in < 30 minutes (vs days of manual setup)

---

## 2. Architecture Overview

### Shared Infrastructure Model (Approved by Marco)

```
┌──────────────────────────────────────────────────────────────────┐
│                   Azure Resource Group (eva-suite-rg)            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure Static Web App (marcopolo483-eva-suite)              │ │
│  │  ├─ /dev/*  (branch: dev, env vars: DEV_*)                 │ │
│  │  ├─ /test/* (branch: test, env vars: TEST_*)               │ │
│  │  └─ /prod/* (branch: main, env vars: PROD_*)               │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure Cosmos DB (eva-suite-cosmos)                          │ │
│  │  ├─ dev-data  (400 RU/s, TTL: 7 days)                     │ │
│  │  ├─ test-data (400 RU/s, TTL: 30 days)                    │ │
│  │  └─ prod-data (1000 RU/s, no TTL, backup enabled)         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure AI Search (eva-suite-search)                          │ │
│  │  ├─ dev-index  (Basic SKU, 50MB storage)                   │ │
│  │  ├─ test-index (Basic SKU, 50MB storage)                   │ │
│  │  └─ prod-index (Standard SKU, 100GB storage)               │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure OpenAI (eva-suite-openai)                             │ │
│  │  ├─ gpt-4o (shared across all environments)                │ │
│  │  ├─ text-embedding-3-small (shared, rate limits enforced)  │ │
│  │  └─ Usage tracked per environment via metadata tags        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure Blob Storage (evasuitestorage)                        │ │
│  │  ├─ dev-docs    (LRS, 30-day lifecycle)                    │ │
│  │  ├─ test-docs   (LRS, 90-day lifecycle)                    │ │
│  │  └─ prod-docs   (GRS, immutable blobs, legal hold)         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure Cache for Redis (eva-suite-redis)                     │ │
│  │  ├─ dev-cache  (Basic C0, 250MB)                           │ │
│  │  ├─ test-cache (Basic C0, 250MB)                           │ │
│  │  └─ prod-cache (Standard C1, 1GB, Redis persistence)       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Azure Key Vault (eva-suite-kv)                              │ │
│  │  ├─ Cosmos connection strings (dev/test/prod)              │ │
│  │  ├─ Azure OpenAI keys                                       │ │
│  │  ├─ Blob Storage keys                                       │ │
│  │  └─ JWT signing secrets                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Monitoring & Logging                                        │ │
│  │  ├─ Log Analytics Workspace (90-day retention)             │ │
│  │  ├─ Application Insights (distributed tracing)             │ │
│  │  └─ Azure Cost Management (budget alerts at $40/month)     │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

**Benefits:**
- **64% Cost Reduction**: $36/month vs $99 (separate environments)
- **Unified DNS**: `eva-suite.marcopolo483.dev` (single SSL certificate)
- **Shared Authentication**: Azure AD B2C tenant across all environments
- **Environment Routing**: Path-based (/dev, /test, /prod) or subdomain-based

---

## 3. Technical Stack

### Primary Technologies

- **IaC Tool**: Terraform 1.6+ (HashiCorp Configuration Language - HCL)
- **Provider**: AzureRM 3.x+ (Azure Resource Manager)
- **State Backend**: Azure Blob Storage (remote state with locking)
- **CI/CD**: GitHub Actions (terraform plan, apply, destroy workflows)
- **Secrets**: Azure Key Vault (connection strings, API keys, JWT secrets)
- **Monitoring**: Azure Monitor, Application Insights, Log Analytics

### Terraform Module Structure

```
eva-infra/
├── terraform/
│   ├── main.tf                  # Root module (calls child modules)
│   ├── variables.tf             # Input variables (environment, region, SKUs)
│   ├── outputs.tf               # Exported values (connection strings, endpoints)
│   ├── providers.tf             # Azure RM provider configuration
│   ├── backend.tf               # Remote state configuration
│   ├── versions.tf              # Terraform + provider version constraints
│   │
│   ├── modules/
│   │   ├── cosmos-db/           # Cosmos DB account + containers
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── ai-search/           # Azure AI Search service + indexes
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── openai/              # Azure OpenAI account + deployments
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── storage/             # Blob Storage account + containers
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── redis/               # Azure Cache for Redis
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── key-vault/           # Key Vault + secrets
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── networking/          # VNet, subnets, NSGs, private endpoints
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   └── monitoring/          # Log Analytics, Application Insights
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   ├── environments/
│   │   ├── dev.tfvars           # Dev-specific values (RU/s, SKUs)
│   │   ├── test.tfvars          # Test-specific values
│   │   └── prod.tfvars          # Prod-specific values
│   │
│   └── scripts/
│       ├── plan.sh              # Terraform plan wrapper
│       ├── apply.sh             # Terraform apply wrapper
│       ├── destroy.sh           # Terraform destroy wrapper
│       └── smoke-test.sh        # Post-deployment validation
│
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml   # PR workflow (plan + validate)
│       ├── terraform-apply.yml  # Merge workflow (apply with approval)
│       └── terraform-destroy.yml # Manual workflow (destroy environment)
│
└── docs/
    ├── SPECIFICATION.md         # This document
    ├── PROVISIONING.md          # Step-by-step deployment guide
    ├── ROLLBACK.md              # Disaster recovery procedures
    └── COST-OPTIMIZATION.md     # Strategies to reduce Azure costs
```

---

## 4. Terraform Modules Specification

### 4.1 Cosmos DB Module

**File**: `modules/cosmos-db/main.tf`

**Resources Created**:
- `azurerm_cosmosdb_account`: Cosmos DB account (serverless or provisioned)
- `azurerm_cosmosdb_sql_database`: SQL API database (`eva-suite-db`)
- `azurerm_cosmosdb_sql_container`: Containers per environment (dev-data, test-data, prod-data)
- `azurerm_private_endpoint`: Private endpoint for VNet integration (prod only)

**Configuration**:
```hcl
resource "azurerm_cosmosdb_account" "eva_suite" {
  name                = "eva-suite-cosmos-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  consistency_policy {
    consistency_level = "Session" # Balance between performance and consistency
  }
  
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  
  capabilities {
    name = "EnableServerless" # or "EnableProvisionedThroughput" for prod
  }
  
  backup {
    type                = var.environment == "prod" ? "Continuous" : "Periodic"
    interval_in_minutes = var.environment == "prod" ? null : 240 # 4 hours for dev/test
    retention_in_hours  = var.environment == "prod" ? null : 168 # 7 days for dev/test
  }
  
  public_network_access_enabled = var.environment == "prod" ? false : true
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_cosmosdb_sql_database" "eva_suite_db" {
  name                = "eva-suite-db"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_suite.name
}

resource "azurerm_cosmosdb_sql_container" "data" {
  name                = "${var.environment}-data"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_suite.name
  database_name       = azurerm_cosmosdb_sql_database.eva_suite_db.name
  partition_key_path  = "/tenantId"
  
  throughput = var.environment == "prod" ? 1000 : 400 # RU/s
  
  default_ttl = var.environment == "dev" ? 604800 : -1 # 7 days for dev, infinite for prod
  
  indexing_policy {
    indexing_mode = "consistent"
    
    included_path {
      path = "/*"
    }
    
    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
}
```

**Outputs**:
- `cosmos_endpoint`: Cosmos DB endpoint URL
- `cosmos_primary_key`: Primary read-write key (stored in Key Vault)
- `cosmos_connection_string`: Full connection string (stored in Key Vault)

---

### 4.2 Azure AI Search Module

**File**: `modules/ai-search/main.tf`

**Resources Created**:
- `azurerm_search_service`: Azure AI Search service
- `azurerm_search_index`: Vector index for embeddings (created via API, not Terraform)
- `azurerm_private_endpoint`: Private endpoint for VNet integration (prod only)

**Configuration**:
```hcl
resource "azurerm_search_service" "eva_suite" {
  name                = "eva-suite-search-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.environment == "prod" ? "standard" : "basic"
  
  replica_count       = var.environment == "prod" ? 2 : 1
  partition_count     = 1
  
  public_network_access_enabled = var.environment == "prod" ? false : true
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# Note: Azure AI Search index creation requires Azure CLI or REST API
# Cannot be managed by Terraform (use az search index create in scripts/)
```

**Outputs**:
- `search_endpoint`: AI Search endpoint URL
- `search_admin_key`: Admin API key (stored in Key Vault)
- `search_query_key`: Query-only API key (for read operations)

---

### 4.3 Azure OpenAI Module

**File**: `modules/openai/main.tf`

**Resources Created**:
- `azurerm_cognitive_account`: Azure OpenAI account
- `azurerm_cognitive_deployment`: GPT-4o deployment
- `azurerm_cognitive_deployment`: text-embedding-3-small deployment
- `azurerm_private_endpoint`: Private endpoint for VNet integration (prod only)

**Configuration**:
```hcl
resource "azurerm_cognitive_account" "eva_suite_openai" {
  name                = "eva-suite-openai-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"
  
  public_network_access_enabled = var.environment == "prod" ? false : true
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.eva_suite_openai.id
  
  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }
  
  sku {
    name     = "Standard"
    capacity = var.environment == "prod" ? 100 : 50 # TPM (tokens per minute)
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-3-small"
  cognitive_account_id = azurerm_cognitive_account.eva_suite_openai.id
  
  model {
    format  = "OpenAI"
    name    = "text-embedding-3-small"
    version = "1"
  }
  
  sku {
    name     = "Standard"
    capacity = var.environment == "prod" ? 1000 : 500 # TPM
  }
}
```

**Outputs**:
- `openai_endpoint`: Azure OpenAI endpoint URL
- `openai_api_key`: API key (stored in Key Vault)
- `gpt4o_deployment_name`: GPT-4o deployment name
- `embedding_deployment_name`: Embedding model deployment name

---

### 4.4 Blob Storage Module

**File**: `modules/storage/main.tf`

**Resources Created**:
- `azurerm_storage_account`: Blob Storage account
- `azurerm_storage_container`: Containers per environment (dev-docs, test-docs, prod-docs)
- `azurerm_storage_management_policy`: Lifecycle management (auto-delete old blobs)
- `azurerm_private_endpoint`: Private endpoint for VNet integration (prod only)

**Configuration**:
```hcl
resource "azurerm_storage_account" "eva_suite" {
  name                     = "evasuitestorage${var.environment}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "GRS" : "LRS"
  
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  
  blob_properties {
    versioning_enabled = var.environment == "prod"
    
    delete_retention_policy {
      days = var.environment == "prod" ? 90 : 7
    }
  }
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_storage_container" "docs" {
  name                  = "${var.environment}-docs"
  storage_account_name  = azurerm_storage_account.eva_suite.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.eva_suite.id
  
  rule {
    name    = "delete-old-blobs"
    enabled = true
    
    filters {
      prefix_match = ["${var.environment}-docs/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.environment == "dev" ? 30 : 365
      }
    }
  }
}
```

**Outputs**:
- `storage_account_name`: Storage account name
- `storage_primary_key`: Primary access key (stored in Key Vault)
- `storage_connection_string`: Full connection string (stored in Key Vault)

---

### 4.5 Redis Module

**File**: `modules/redis/main.tf`

**Resources Created**:
- `azurerm_redis_cache`: Azure Cache for Redis
- `azurerm_private_endpoint`: Private endpoint for VNet integration (prod only)

**Configuration**:
```hcl
resource "azurerm_redis_cache" "eva_suite" {
  name                = "eva-suite-redis-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.environment == "prod" ? 1 : 0 # C1 for prod, C0 for dev/test
  family              = var.environment == "prod" ? "C" : "C"
  sku_name            = var.environment == "prod" ? "Standard" : "Basic"
  
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
  
  redis_configuration {
    maxmemory_policy = "allkeys-lru" # Evict least recently used keys when memory full
  }
  
  public_network_access_enabled = var.environment == "prod" ? false : true
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}
```

**Outputs**:
- `redis_hostname`: Redis hostname
- `redis_port`: Redis SSL port (6380)
- `redis_primary_key`: Primary access key (stored in Key Vault)

---

### 4.6 Key Vault Module

**File**: `modules/key-vault/main.tf`

**Resources Created**:
- `azurerm_key_vault`: Key Vault for secrets
- `azurerm_key_vault_secret`: Secrets for connection strings, API keys
- `azurerm_private_endpoint`: Private endpoint for VNet integration (prod only)

**Configuration**:
```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "eva_suite" {
  name                = "eva-suite-kv-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  enable_rbac_authorization = true # Use RBAC instead of access policies
  
  network_acls {
    default_action = var.environment == "prod" ? "Deny" : "Allow"
    bypass         = "AzureServices"
  }
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# Example secret: Cosmos DB connection string
resource "azurerm_key_vault_secret" "cosmos_connection_string" {
  name         = "cosmos-connection-string"
  value        = var.cosmos_connection_string
  key_vault_id = azurerm_key_vault.eva_suite.id
  
  depends_on = [azurerm_key_vault.eva_suite]
}

# Grant Terraform service principal read access
resource "azurerm_role_assignment" "terraform_kv_secrets_user" {
  scope                = azurerm_key_vault.eva_suite.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_client_config.current.object_id
}
```

**Outputs**:
- `key_vault_id`: Key Vault resource ID
- `key_vault_uri`: Key Vault URI (`https://eva-suite-kv-prod.vault.azure.net/`)

---

### 4.7 Networking Module

**File**: `modules/networking/main.tf`

**Resources Created**:
- `azurerm_virtual_network`: VNet for private networking
- `azurerm_subnet`: Subnets for each service (Cosmos DB, AI Search, OpenAI, etc.)
- `azurerm_network_security_group`: NSG with rules
- `azurerm_private_dns_zone`: Private DNS zones for Azure services
- `azurerm_private_endpoint`: Private endpoints for services

**Configuration** (prod only, dev/test use public endpoints):
```hcl
resource "azurerm_virtual_network" "eva_suite" {
  count               = var.environment == "prod" ? 1 : 0
  name                = "eva-suite-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_subnet" "cosmos" {
  count                = var.environment == "prod" ? 1 : 0
  name                 = "cosmos-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.eva_suite[0].name
  address_prefixes     = ["10.0.1.0/24"]
  
  service_endpoints = ["Microsoft.AzureCosmosDB"]
}

resource "azurerm_network_security_group" "eva_suite" {
  count               = var.environment == "prod" ? 1 : 0
  name                = "eva-suite-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}
```

---

### 4.8 Monitoring Module

**File**: `modules/monitoring/main.tf`

**Resources Created**:
- `azurerm_log_analytics_workspace`: Log Analytics workspace
- `azurerm_application_insights`: Application Insights for distributed tracing
- `azurerm_monitor_action_group`: Alert action group (email/SMS)
- `azurerm_monitor_metric_alert`: Cost alert (budget exceeded)

**Configuration**:
```hcl
resource "azurerm_log_analytics_workspace" "eva_suite" {
  name                = "eva-suite-logs-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 90 : 30
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_application_insights" "eva_suite" {
  name                = "eva-suite-insights-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.eva_suite.id
  application_type    = "web"
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_monitor_action_group" "eva_suite" {
  name                = "eva-suite-alerts-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "EVA Alerts"
  
  email_receiver {
    name          = "Marco Presta"
    email_address = var.alert_email
  }
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "azurerm_monitor_metric_alert" "cost_budget" {
  name                = "eva-suite-cost-alert-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_resource_group.eva_suite.id]
  description         = "Alert when monthly cost exceeds $40"
  
  criteria {
    metric_namespace = "Microsoft.CostManagement/budgets"
    metric_name      = "ActualCost"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 40
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.eva_suite.id
  }
  
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}
```

---

## 5. CI/CD Workflows

### 5.1 Terraform Plan Workflow

**File**: `.github/workflows/terraform-plan.yml`

**Trigger**: Pull request to `main` branch

**Steps**:
1. Checkout code
2. Setup Terraform
3. Terraform init (with remote backend)
4. Terraform validate
5. Terraform plan (for each environment: dev, test, prod)
6. Post plan output as PR comment
7. Security scan (tfsec)

**Example**:
```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-plan.yml'

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, test, prod]
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0
      
      - name: Terraform Init
        run: |
          cd terraform
          terraform init \
            -backend-config="resource_group_name=${{ secrets.TFSTATE_RG }}" \
            -backend-config="storage_account_name=${{ secrets.TFSTATE_SA }}" \
            -backend-config="container_name=tfstate" \
            -backend-config="key=${{ matrix.environment }}.tfstate"
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
      
      - name: Terraform Validate
        run: |
          cd terraform
          terraform validate
      
      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan \
            -var-file="environments/${{ matrix.environment }}.tfvars" \
            -out=tfplan-${{ matrix.environment }}
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
      
      - name: Security Scan
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: terraform
```

---

### 5.2 Terraform Apply Workflow

**File**: `.github/workflows/terraform-apply.yml`

**Trigger**: Push to `main` branch (after PR merge)

**Approval Gate**: Requires manual approval for prod environment

**Steps**:
1. Checkout code
2. Setup Terraform
3. Terraform init
4. Terraform apply (with auto-approve for dev/test, manual approval for prod)
5. Run smoke tests
6. Post deployment summary

---

### 5.3 Terraform Destroy Workflow

**File**: `.github/workflows/terraform-destroy.yml`

**Trigger**: Manual workflow dispatch (only authorized users)

**Steps**:
1. Confirm environment to destroy (dev/test only, prod requires manual CLI)
2. Terraform destroy (with confirmation)
3. Clean up state files

---

## 6. Quality Gates (All Must Pass)

### 1. Terraform Validation: 100%
- **Tool**: `terraform validate`
- **Command**: `terraform validate`
- **Target**: Zero syntax errors
- **Evidence**: CI/CD logs showing validation passed

### 2. Security Scan: Zero High/Critical Issues
- **Tool**: tfsec (Terraform security scanner)
- **Command**: `tfsec terraform/`
- **Target**: Zero high/critical vulnerabilities
- **Evidence**: tfsec report

### 3. Cost Estimation: < $40/month
- **Tool**: Infracost (cost estimation for Terraform)
- **Command**: `infracost breakdown --path terraform/`
- **Target**: < $40/month for all environments
- **Evidence**: Infracost report

### 4. Deployment Success: 100%
- **Metric**: All resources created without errors
- **Tool**: Terraform apply output
- **Evidence**: `Apply complete! Resources: X added, 0 changed, 0 destroyed.`

### 5. Smoke Tests: 100% Pass
- **Tests**: Cosmos DB connectivity, AI Search reachable, OpenAI API working, Blob Storage accessible
- **Tool**: Custom Bash scripts (`scripts/smoke-test.sh`)
- **Evidence**: Test output showing all checks passed

### 6. State Consistency: No Drift
- **Metric**: `terraform plan` shows no changes (after apply)
- **Tool**: `terraform plan -detailed-exitcode`
- **Evidence**: Exit code 0 (no changes)

### 7. Backup & Restore: 100% Success
- **Test**: Destroy prod, restore from backup, verify data integrity
- **Tool**: Azure CLI + Cosmos DB restore API
- **Evidence**: Data restored successfully

### 8. Documentation: 100% Complete
- **Sections**: PROVISIONING.md, ROLLBACK.md, COST-OPTIMIZATION.md
- **Evidence**: All docs exist with step-by-step guides

### 9. Secrets Management: Zero Secrets in Code
- **Tool**: git-secrets, trufflehog
- **Evidence**: No Azure keys, connection strings, or passwords in Git history

### 10. Multi-Environment Isolation: 100%
- **Test**: Create user in dev, verify NOT visible in test/prod
- **Tool**: Custom Cosmos DB query script
- **Evidence**: Zero cross-environment data leakage

### 11. Rollback Success: < 5 minutes
- **Metric**: Time to rollback failed deployment
- **Tool**: `terraform destroy` + `terraform apply` with previous state
- **Evidence**: Rollback completed in < 5 minutes

### 12. Monitoring Alerts: 100% Functional
- **Test**: Trigger cost alert (simulate $40 spend), verify email received
- **Tool**: Azure Monitor alert simulation
- **Evidence**: Email/SMS received within 5 minutes

---

## 7. Implementation Phases (4 Phases, 6 Weeks)

### Phase 1: Core Infrastructure (Weeks 1-2)

**Goal**: Provision Cosmos DB, Blob Storage, Key Vault

**Tasks**:
1. Setup Terraform project structure
2. Configure Azure RM provider + remote state backend
3. Create Cosmos DB module (account + containers)
4. Create Blob Storage module (account + containers)
5. Create Key Vault module (vault + secrets)
6. Write Terraform variables for dev/test/prod
7. CI/CD: GitHub Actions for `terraform plan`
8. Smoke tests: Connectivity checks

**Deliverables**:
- Cosmos DB provisioned with dev/test/prod containers
- Blob Storage provisioned with lifecycle policies
- Key Vault storing connection strings
- CI/CD pipeline running `terraform plan` on PR

**Evidence**:
- Azure Portal screenshots showing resources
- Terraform apply output showing success
- Smoke tests passing

---

### Phase 2: AI Services (Weeks 3-4)

**Goal**: Provision Azure AI Search, Azure OpenAI, Redis

**Tasks**:
1. Create Azure AI Search module (service + indexes)
2. Create Azure OpenAI module (account + deployments: GPT-4o, embeddings)
3. Create Redis module (cache instances)
4. Configure private endpoints (prod only)
5. Update Key Vault with AI service keys
6. CI/CD: Add `terraform apply` workflow (with approval gates)
7. Smoke tests: AI Search query, OpenAI API call, Redis set/get

**Deliverables**:
- Azure AI Search indexed (empty, ready for documents)
- Azure OpenAI deployments active (GPT-4o + embeddings)
- Redis cache operational
- Private endpoints configured for prod

**Evidence**:
- AI Search query returns 200 OK
- OpenAI API call returns valid response
- Redis set/get working
- Terraform apply successful

---

### Phase 3: Networking & Security (Week 5)

**Goal**: Configure VNet, NSGs, private endpoints, RBAC

**Tasks**:
1. Create Networking module (VNet, subnets, NSGs)
2. Configure private endpoints for all services (prod)
3. Setup RBAC roles (Managed Identity for services)
4. Configure Azure Firewall rules (if needed)
5. Security scan with tfsec (fix all high/critical issues)
6. Update Key Vault access policies (deny public access in prod)
7. Smoke tests: Verify private endpoint connectivity

**Deliverables**:
- VNet provisioned with subnets
- Private endpoints active for prod
- RBAC roles assigned
- tfsec scan passing

**Evidence**:
- VNet diagram showing subnets
- Private endpoint connectivity test passed
- tfsec report with zero high/critical issues

---

### Phase 4: Monitoring & Docs (Week 6)

**Goal**: Setup monitoring, alerts, documentation

**Tasks**:
1. Create Monitoring module (Log Analytics, Application Insights)
2. Configure cost alerts ($40/month threshold)
3. Setup Grafana dashboards (optional)
4. Write PROVISIONING.md (step-by-step deployment guide)
5. Write ROLLBACK.md (disaster recovery procedures)
6. Write COST-OPTIMIZATION.md (strategies to reduce costs)
7. Final smoke tests (end-to-end)
8. Load testing (optional)

**Deliverables**:
- Monitoring operational (logs, metrics, alerts)
- Cost alert triggered successfully
- All documentation complete
- All 12 quality gates passed

**Evidence**:
- Application Insights showing traces
- Cost alert email received
- Documentation reviewed and approved
- Quality gates report

---

## 8. References

### Terraform Azure Patterns
- **Azure Provider Docs**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Terraform Best Practices**: https://www.terraform.io/docs/language/modules/develop/best-practices.html

### Reference Implementations
- **PubSec Info Assistant**: `PubSec-Info-Assistant/infra/main.tf` (Terraform + ARM templates)
- **EVA Orchestrator Templates**: `eva-orchestrator/templates/eva-infra/` (module structure)

### Azure Services
- **Cosmos DB**: https://learn.microsoft.com/azure/cosmos-db/
- **Azure AI Search**: https://learn.microsoft.com/azure/search/
- **Azure OpenAI**: https://learn.microsoft.com/azure/ai-services/openai/

### Cost Optimization
- **Azure Pricing Calculator**: https://azure.microsoft.com/en-us/pricing/calculator/
- **Shared Infrastructure**: Marco's approved model ($36/month)

---

## 9. Next Steps

1. **Marco Opens eva-infra Workspace**:
   ```powershell
   cd "C:\Users\marco\Documents\_AI Dev\EVA Suite"
   code eva-infra
   ```

2. **Run Startup Script**:
   ```powershell
   .\_MARCO-use-this-to-tell_copilot-to-read-repo-specific-instructions.ps1
   ```

3. **Give Task**:
   ```
   Implement Phase 1: Core Infrastructure (Cosmos DB, Blob Storage, Key Vault).
   Follow specification TO THE LETTER.
   Use PubSec Info Assistant patterns (Terraform + ARM templates).
   Create Terraform modules for each resource type.
   Setup remote state backend.
   Write CI/CD workflows for terraform plan.
   Show terraform apply output + smoke test results when done.
   ```

---

**END OF SPECIFICATION**
