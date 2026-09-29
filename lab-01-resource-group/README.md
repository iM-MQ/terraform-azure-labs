# Lab 01: Resource Group and the Terraform Workflow

## Overview

| | |
|---|---|
| **Goal** | Learn the core Terraform workflow by creating, changing and destroying an Azure resource group |
| **Deploys** | One resource group in UK South, with tags |
| **Provider** | `azurerm` v4 |
| **Cost** | Free (resource groups have no charge) |
| **Time** | About 20-30 minutes |

## Files

| File | Purpose |
|---|---|
| `providers.tf` | Tells Terraform to use Azure (the `azurerm` provider) and pins the version |
| `variables.tf` | Inputs that can be changed: the resource group name and region |
| `main.tf` | What to build: the resource group and its tags |
| `outputs.tf` | Information displayed after the build: name and region |
| `.terraform.lock.hcl` | Records the exact provider version used, so builds are repeatable |

### How the code reads

```hcl
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}
```

- `azurerm_resource_group` is the **type** of thing to create.
- `lab` is the **label** used to refer to it elsewhere in the code.
- `var.resource_group_name` and `var.location` pull values from `variables.tf`.

---

## Step-by-step walkthrough

### Step 1: Sign in to Azure

```powershell
az login
az account show --output table
```

- `az login` opens a browser to sign in to Azure.
- `az account show` confirms which subscription is active. Check that **State** is `Enabled`.

### Step 2: Tell Terraform which subscription to use

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

- Stores the subscription ID in an environment variable for this PowerShell session only.
- The azurerm provider v4 requires a subscription ID; passing it this way keeps it **out of the code** and out of GitHub.
- It must be run again in each new PowerShell window.

Check it is set:

```powershell
if ($env:ARM_SUBSCRIPTION_ID) { "Subscription ID is set" } else { "NOT set" }
```

### Step 3: Initialise the project

```powershell
terraform init
```

- Downloads the Azure provider (plugin) defined in `providers.tf`.
- Creates a hidden `.terraform` folder (excluded from Git) and the `.terraform.lock.hcl` file (committed to Git).
- Must be run first in any new Terraform project.

Expected output:

```
Terraform has been successfully initialized!
```

### Step 4: Format and validate

```powershell
terraform fmt
terraform validate
```

- `terraform fmt` tidies the code layout. It prints nothing if the files are already neat.
- `terraform validate` checks the code for errors **without** connecting to Azure.

Expected output:

```
Success! The configuration is valid.
```

### Step 5: Preview the changes

```powershell
terraform plan
```

- Connects to Azure and shows **exactly** what would change, without changing anything.
- This is the most important command: always read the plan before applying.

Output:

```
  # azurerm_resource_group.lab will be created
  + resource "azurerm_resource_group" "lab" {
      + id       = (known after apply)
      + location = "uksouth"
      + name     = "rg-tflab01-uks"
      + tags     = {
          + "environment" = "lab"
          + "managed_by"  = "terraform"
          + "project"     = "terraform-azure-labs"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

`(known after apply)` means Azure assigns that value, such as the resource ID, once it is built.

**Plan symbols:**

| Symbol | Meaning |
|---|---|
| `+` | Create |
| `~` | Update in place |
| `-` | Destroy |
| `-/+` | Destroy and recreate (replace) |

### Step 6: Build it

```powershell
terraform apply
```

- Shows the plan again and asks for confirmation. Only typing `yes` proceeds.

Output:

```
azurerm_resource_group.lab: Creating...
azurerm_resource_group.lab: Creation complete after 23s [id=/subscriptions/<subscription-id>/resourceGroups/rg-tflab01-uks]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
resource_group_location = "uksouth"
resource_group_name = "rg-tflab01-uks"
```

### Step 7: Verify in Azure

```powershell
az group show --name rg-tflab01-uks --output table
terraform state list
```

- `az group show` confirms the resource group exists in Azure.
- `terraform state list` shows what Terraform is managing: `azurerm_resource_group.lab`.
- A `terraform.tfstate` file now exists locally. This is Terraform's record of what it built. It can contain sensitive data, so it is excluded from Git.

---

## Tests carried out

### Test 1: In-place update (safe change)

Added an `owner` tag to `main.tf`, then ran `terraform plan`:

```
  ~ update in-place

      ~ tags = {
            "environment" = "lab"
            "managed_by"  = "terraform"
          + "owner"       = "iM-MQ"
            "project"     = "terraform-azure-labs"
        }

Plan: 0 to add, 1 to change, 0 to destroy.
```

- `~` means the existing resource is modified, not rebuilt.
- Applied with `terraform apply`, then confirmed with:

```powershell
az group show --name rg-tflab01-uks --query tags
```

### Test 2: Destructive change (reviewed, not applied)

Changed the region in `variables.tf` from `uksouth` to `ukwest`, then ran `terraform plan`:

```
-/+ destroy and then create replacement

      ~ location = "uksouth" -> "ukwest" # forces replacement

Plan: 1 to add, 0 to change, 1 to destroy.
```

- A resource group's region cannot be changed, so Terraform would **delete and recreate** it.
- In a real environment, everything inside the resource group would be deleted too.
- The plan was **not applied**. The region was changed back, and `terraform plan` confirmed:

```
No changes. Your infrastructure matches the configuration.
```

### Test 3: Drift detection

Added a tag (`test = manual`) directly in the Azure portal, bypassing Terraform, then ran `terraform plan`:

```
  ~ update in-place

      ~ tags = {
            ...
          - "test" = "manual" -> null
        }

Plan: 0 to add, 1 to change, 0 to destroy.
```

- Terraform detected the manual change (**drift**) and planned to remove it, because it is not in the code.
- Applied to restore Azure to match the code.

### Step 8: Clean up

```powershell
terraform destroy
az group list --output table
```

- `terraform destroy` removes everything this configuration created, after typing `yes`.
- `az group list` confirms `rg-tflab01-uks` no longer exists.

```
Destroy complete! Resources: 1 destroyed.
```

---

## Command reference

| Command | What it does |
|---|---|
| `az login` | Sign in to Azure |
| `az account show` | Show the active subscription |
| `terraform init` | Download providers and prepare the folder |
| `terraform fmt` | Tidy code formatting |
| `terraform validate` | Check the code for errors |
| `terraform plan` | Preview changes without making them |
| `terraform apply` | Make the changes (after confirmation) |
| `terraform state list` | List resources Terraform is managing |
| `terraform destroy` | Remove everything the configuration created |

## Troubleshooting (issues I hit)

| Problem | Cause | Fix |
|---|---|---|
| `terraform : The term 'terraform' is not recognized` | Terraform not installed | `winget install --id Hashicorp.Terraform -e`, then reopen PowerShell |
| `az : The term 'az' is not recognized` | Azure CLI not installed | `winget install --id Microsoft.AzureCLI -e`, then reopen PowerShell |
| Subscription ID check returned `NOT set` | The environment variable had not been set in the current session | Run `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` |
| "Terraform is out of date" notice | A newer Terraform version is available | Optional: `winget upgrade --id Hashicorp.Terraform -e` |

## What I learned

- `terraform plan` is the safety net: it shows the exact impact of a change before anything is touched, much like a change-advisory risk assessment. Any "destroy" in a plan needs careful review.
- Some changes, like a resource group's region, cannot be made in place and force a full replacement.
- The state file is Terraform's record of what it manages. It can hold sensitive data, so it is excluded from Git.
- The subscription ID is passed as an environment variable rather than hard-coded in the configuration.
- The code is the source of truth: manual changes in the portal are detected as drift and reverted.
- Resources should always be destroyed after a lab to control cost.