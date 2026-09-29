# Terraform Azure Labs

Hands-on labs learning **Terraform** by building real **Azure** infrastructure as code, using the `azurerm` provider. Each lab builds on the previous one and is deployed, tested and destroyed in my own Azure subscription.

**Requires:** an Azure subscription, Terraform and the Azure CLI. See [Prerequisites](#prerequisites) for install steps.

| Lab | Topic | Status |
|---|---|---|
| [01](lab-01-resource-group) | Resource group and the Terraform workflow (init, plan, apply, destroy, drift) | Complete ✅ |
| 02 | Virtual network, subnets and network security groups | Planned ⏳ |
| 03 | Variables, outputs and reusable modules | Planned ⏳ |
| 04 | Remote state in Azure Storage | Planned ⏳ |
| 05 | Capstone: deploy the [IT Asset Register](https://github.com/iM-MQ/docker-asset-register) to Azure | Planned ⏳ |

## Practices followed
- State files and variable files are never committed (see `.gitignore`)
- No subscription IDs or secrets in code; credentials come from the Azure CLI session
- Provider versions pinned for repeatable builds
- Every change reviewed with `terraform plan` before `apply`
- All lab resources destroyed after use to control cost

## Prerequisites

| Requirement | Version used | Purpose | Install (Windows) |
|---|---|---|---|
| Azure subscription | Free account | Where the resources are deployed | [azure.microsoft.com/free](https://azure.microsoft.com/free) |
| Terraform | 1.16.x (1.9 or later required) | Builds the infrastructure from code | `winget install --id Hashicorp.Terraform -e` |
| Azure CLI | 2.90 | Signs Terraform in to Azure | `winget install --id Microsoft.AzureCLI -e` |
| Git | 2.x | Clones this repository | `winget install --id Git.Git -e` |
| VS Code + HashiCorp Terraform extension | Latest (optional) | Editing with syntax highlighting and validation | `winget install --id Microsoft.VisualStudioCode -e` |

For macOS or Linux, see the official install guides for [Terraform](https://developer.hashicorp.com/terraform/install) and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).

> After installing, close and reopen your terminal so the new commands are recognised.

### Check everything is installed
```powershell
terraform -version
az version
git --version
```

## First-time setup

**1. Sign in to Azure**
```powershell
az login
```

**2. Tell Terraform which subscription to use** (needed in each new terminal session)
```powershell
# Windows PowerShell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```
```bash
# macOS / Linux
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```
This keeps the subscription ID out of the code and out of source control.

**3. Recommended: set a budget alert** in the Azure portal under **Cost Management > Budgets**, so you are emailed if spending rises unexpectedly.

## Running a lab

```powershell
git clone https://github.com/iM-MQ/terraform-azure-labs.git
cd terraform-azure-labs/lab-01-resource-group

terraform init       # download the Azure provider
terraform plan       # preview the changes
terraform apply      # build it (type yes to confirm)
terraform destroy    # remove everything when finished
```

## Cost

Each lab README notes what it deploys. Lab 01 creates only a resource group, which has no cost. Always run `terraform destroy` when you finish a lab to avoid charges.