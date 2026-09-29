# Lab 01: Resource Group and the Terraform Workflow

## What this lab deploys
A single Azure resource group in UK South, with standard tags, using the `azurerm` provider (v4).

## Files
| File | Purpose |
|---|---|
| `providers.tf` | Terraform and azurerm provider version constraints |
| `variables.tf` | Input variables (name, location) with defaults |
| `main.tf` | The resource group definition |
| `outputs.tf` | Values displayed after deployment |

## How to run
```powershell
az login
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
terraform init
terraform plan
terraform apply
terraform destroy
```

## What I tested
- **Full lifecycle:** init, fmt, validate, plan, apply and destroy.
- **In-place update:** adding an `owner` tag showed `~ update in-place`, changing 1 resource with nothing destroyed.
- **Destructive change:** changing the region from UK South to UK West showed `-/+ must be replaced` with `# forces replacement`. The plan was reviewed and **not** applied.
- **Drift detection:** a tag added manually in the Azure portal was detected by `terraform plan` (`- "test" = "manual" -> null`) and removed on the next apply.

## What I learned
- `terraform plan` is the safety net: it shows the exact impact of a change before anything is touched, much like a change-advisory risk assessment. Any "destroy" in a plan needs careful review.
- Some changes, like a resource group's region, cannot be made in place and force a full replacement.
- The state file is Terraform's record of what it manages. It can hold sensitive data, so it is excluded from Git.
- The subscription ID is passed as an environment variable rather than hard-coded in the configuration.
- The code is the source of truth: manual changes in the portal are detected as drift and reverted.
