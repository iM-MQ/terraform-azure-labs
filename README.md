# Terraform Azure Labs

Hands-on labs learning **Terraform** by building real **Azure** infrastructure as code, using the `azurerm` provider. Each lab builds on the previous one and is deployed, tested and destroyed in my own Azure subscription.

**Requires:** an Azure subscription, Terraform and the Azure CLI. See [Prerequisites](#prerequisites) for install steps.

| Lab | Topic | Status |
|---|---|---|
| [01](lab-01-resource-group) | Resource group and the Terraform workflow (init, plan, apply, destroy, drift) | Complete ✅ |
| [02](lab-02-virtual-network) | Virtual network, subnets and NSGs, with tier segmentation and drift detection | Complete ✅ |
| [03](lab-03-modules) | Reusable modules, input validation and multiple environments from one codebase | Complete ✅ |
| 04 | Remote state in Azure Storage | Planned ⏳ |
| 05 | Capstone: deploy the [IT Asset Register](https://github.com/iM-MQ/docker-asset-register) to Azure | Planned ⏳ |

## What is Terraform?

Terraform is an **infrastructure as code (IaC)** tool made by HashiCorp. Instead of building infrastructure by clicking through the Azure portal, you describe what you want in text files, and Terraform builds it for you. Change the files and Terraform updates the infrastructure to match. Delete it all with one command when you are done.

The same files can be run again and again and will produce the same result every time, which is the whole point.

### How it works

```
  Write          Plan             Apply            Track
 ───────►  ───────────────►  ───────────────►  ───────────────
 .tf files   Preview exactly    Terraform makes   A state file
 describe    what will be       the changes in    records what
 what you    added, changed     Azure, in the     Terraform has
 want        or destroyed       right order       built
```

- **Providers** are plugins that let Terraform talk to a platform. These labs use `azurerm` for Azure, but there are providers for AWS, Google Cloud, Entra ID, GitHub, Cloudflare and hundreds more.
- **`terraform plan`** shows the impact of a change before anything is touched. It works a lot like the risk and impact assessment on a change request before it goes to CAB.
- **`terraform apply`** makes the changes, working out the order itself from how the resources depend on each other.
- **The state file** is Terraform's record of what it manages. It lets Terraform spot drift, where someone has changed something by hand outside the code.

### Why organisations use it

| Benefit | What it means in practice |
|---|---|
| **Consistency** | Dev, test and production are built from the same code, so they do not drift apart |
| **Visibility** | Every change is previewed with `plan` before it happens, reducing the risk of surprises |
| **Audit trail** | The code lives in Git, so every change has a record of who changed what, when and why |
| **Drift detection** | Manual changes in the portal are spotted and can be reverted |
| **Speed** | Environments that took days to build by hand can be created in minutes |
| **Disaster recovery** | If an environment is lost, it can be rebuilt from code rather than from memory or documentation |
| **Cost control** | Test environments can be destroyed at the end of the day and rebuilt when needed |
| **Reuse** | Common patterns, like a standard network, can be packaged as modules and reused across projects |

### What it can be used for

- **Azure landing zones:** management groups, Azure Policy, RBAC and hub-and-spoke networking
- **Networking:** VNets, subnets, NSGs, VPN gateways, firewalls and DNS
- **Compute:** virtual machines, Azure Virtual Desktop and scale sets
- **Containers:** Azure Kubernetes Service (AKS) and Azure Container Registry
- **Identity:** Entra ID groups, app registrations and Conditional Access policies (using the `azuread` provider)
- **Storage and security:** storage accounts, Key Vault and backup policies
- **Multi-environment deployments:** the same code deployed to dev, test and production with different settings
- **CI/CD pipelines:** infrastructure changes planned and applied automatically from GitHub Actions or Azure DevOps

### Why I am learning it

Most of my career has been hands-on infrastructure work: domain migrations, hybrid identity, Intune rollouts and, at one point, rebuilding an entire 700+ user estate from scratch after a malware attack. That rebuild is where I really saw the value of having infrastructure defined somewhere other than in people's heads. Terraform is the natural next step from the work I already do, and these labs are how I am building that skill properly, one step at a time.
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

Each lab README notes what it deploys. Labs 01 to 03 use only free resources (resource groups, virtual networks, subnets and NSGs). Always run `terraform destroy` when you finish a lab to avoid charges.