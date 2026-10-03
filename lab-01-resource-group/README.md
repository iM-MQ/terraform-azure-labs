# Lab 01: Resource Group and the Terraform Workflow

## Overview

| | |
|---|---|
| **Goal** | Learn the core Terraform workflow by creating, changing and destroying an Azure resource group |
| **Deploys** | One resource group in UK South, with tags |
| **Provider** | `azurerm` v4 |
| **Cost** | Free (resource groups have no charge) |
| **Time** | About 30 minutes, plus tool installation |

This was my first Terraform lab. I wanted to understand the full workflow before building anything more complex: writing the code, previewing changes, applying them, changing things safely and cleaning up. I kept the infrastructure deliberately simple (a single resource group) so the focus stayed on how Terraform behaves.

Below I have written up every step I took, the commands I ran and what I saw, so anyone can follow the same process.

---

## Following along?

If you want to repeat this lab yourself, a few pointers:

- I ran every command in **Windows PowerShell** (Start, type `PowerShell`, select **Windows PowerShell**).
- Each command is in its own box. Run **one line at a time**, pressing **Enter** after each, and let it finish before running the next.
- Anything in `<angle brackets>` needs replacing with your own value, **brackets included**. For example, `<your-folder-path>` becomes `C:\terraform-labs`.
- Boxes marked **What I saw** show my output, so you can compare. They are not commands to run.
- Code in `hcl` boxes is Terraform code. It goes **inside the `.tf` files**, not into PowerShell.
- When Terraform asks `Enter a value:`, type the full word `yes` and press **Enter**. Anything else cancels.

The tools needed are listed in the [main README prerequisites](../README.md#prerequisites), and Step 1 below shows how I installed them.

---

## Files in this lab

| File | Purpose |
|---|---|
| `providers.tf` | Tells Terraform to use Azure (the `azurerm` provider) and pins the version |
| `variables.tf` | Inputs that can be changed: the resource group name and region |
| `main.tf` | What to build: the resource group and its tags |
| `outputs.tf` | Information displayed after the build: name and region |
| `.terraform.lock.hcl` | Created automatically by `terraform init`. Records the exact provider version used |

### How the code reads

```hcl
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}
```

- `azurerm_resource_group` is the **type** of thing to create.
- `lab` is the **label** I use to refer to it elsewhere in the code.
- `var.resource_group_name` and `var.location` pull their values from `variables.tf`.

### Plan symbols

These appear throughout Terraform's output, so they are worth knowing before starting:

| Symbol | Meaning |
|---|---|
| `+` | Create |
| `~` | Update in place |
| `-` | Destroy |
| `-/+` | Destroy and recreate (replace) |

---

## How I built it

### Step 1: Installed the tools

I checked whether Terraform was installed:

```powershell
terraform -version
```

**What I saw:**

```
terraform : The term 'terraform' is not recognized as the name of a cmdlet...
```

It was not installed, so I installed it:

```powershell
winget install --id Hashicorp.Terraform -e
```

I closed PowerShell completely and opened a new window, so it would pick up the new command, then checked again:

```powershell
terraform -version
```

**What I saw:**

```
Terraform v1.16.2
on windows_amd64
```

I did the same for the Azure CLI, which Terraform uses to sign in to Azure. It was also missing, so I installed it:

```powershell
winget install --id Microsoft.AzureCLI -e
```

After reopening PowerShell:

```powershell
az version
```

**What I saw:**

```
{
  "azure-cli": "2.90.0",
  ...
}
```

> If `winget` is not available on your machine, both tools can be downloaded from the links in the [main README prerequisites](../README.md#prerequisites).

### Step 2: Signed in to Azure

```powershell
az login
```

This opened a browser to sign in. I only have one subscription, so when asked to choose I pressed **Enter** to keep the default. I then confirmed it was active:

```powershell
az account show --output table
```

**State** showed `Enabled`.

Before building anything, I also set up a **budget alert** in the Azure portal (**Cost Management > Budgets**) so I would be emailed if spending started to rise.

### Step 3: Set up the repository folder

I created a folder for all my Terraform labs and moved into it:

```powershell
mkdir C:\terraform-labs
```

```powershell
cd C:\terraform-labs
```

I made it a Git repository so the work could go to GitHub:

```powershell
git init
```

**What I saw:**

```
Initialized empty Git repository in C:/terraform-labs/.git/
```

I then created a `.gitignore` file, to stop sensitive and generated files ever being uploaded:

```powershell
notepad .gitignore
```

I clicked **Yes** to create it, pasted in the following, saved and closed it:

```
# Terraform working folders
.terraform/

# State files: can contain sensitive data, never commit
*.tfstate
*.tfstate.*

# Variable files: may contain secrets
*.tfvars
*.tfvars.json

# Crash logs and local overrides
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
```

The most important entry is `*.tfstate`. Terraform keeps a state file recording everything it has built, and it can contain sensitive details, so it must never go to GitHub.

### Step 4: Created the lab folder

```powershell
mkdir lab-01-resource-group
```

```powershell
cd lab-01-resource-group
```

### Step 5: Wrote the provider file

I created `providers.tf`, which tells Terraform to use Azure:

```powershell
notepad providers.tf
```

I clicked **Yes**, pasted in the following, saved and closed it:

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

- `required_version` means Terraform 1.9 or newer is needed.
- `version = "~> 4.0"` pins the Azure provider to version 4, so a future version 5 cannot change behaviour unexpectedly. It is the same idea as pinning a Docker image version.
- `features {}` is required by the Azure provider, even when empty.

### Step 6: Wrote the variables file

```powershell
notepad variables.tf
```

I clicked **Yes**, pasted in the following, saved and closed it:

```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-tflab01-uks"
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "uksouth"
}
```

The name follows a common Azure naming convention: `rg` (resource group), then its purpose (`tflab01`), then the region (`uks` for UK South).

### Step 7: Wrote the main configuration

```powershell
notepad main.tf
```

I clicked **Yes**, pasted in the following, saved and closed it:

```hcl
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "lab"
    project     = "terraform-azure-labs"
    managed_by  = "terraform"
  }
}
```

The `managed_by = "terraform"` tag tells anyone looking in the portal that this resource should not be changed by hand.

### Step 8: Wrote the outputs file

```powershell
notepad outputs.tf
```

I clicked **Yes**, pasted in the following, saved and closed it:

```hcl
output "resource_group_name" {
  description = "The name of the resource group created"
  value       = azurerm_resource_group.lab.name
}

output "resource_group_location" {
  description = "The region the resource group is in"
  value       = azurerm_resource_group.lab.location
}
```

I checked all four files were there:

```powershell
dir
```

**What I saw:**

```
Mode    Name
----    ----
-a----  main.tf
-a----  outputs.tf
-a----  providers.tf
-a----  variables.tf
```

> If a file shows as `main.tf.txt`, Notepad has added `.txt` to the name. Fix it with `Rename-Item main.tf.txt main.tf`.

### Step 9: Told Terraform which subscription to use

Version 4 of the Azure provider needs to know the subscription ID. Rather than typing it into the code, I stored it in a temporary setting that Terraform reads:

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

This prints nothing when it works, so I checked it:

```powershell
if ($env:ARM_SUBSCRIPTION_ID) { "Subscription ID is set" } else { "NOT set" }
```

My first check said `NOT set`, because I had not run the line above it in that window. After running the `$env:ARM_SUBSCRIPTION_ID` line and checking again:

**What I saw:**

```
Subscription ID is set
```

> This setting is lost when PowerShell is closed, so the `$env:ARM_SUBSCRIPTION_ID` line needs running again in every new window.

### Step 10: Initialised Terraform

```powershell
terraform init
```

This downloaded the Azure provider into a hidden `.terraform` folder and created `.terraform.lock.hcl`.

**What I saw:**

```
Terraform has been successfully initialized!
```

I checked the new files, including hidden ones:

```powershell
dir -Force
```

- `.terraform` is the downloaded provider. It is excluded from Git by `.gitignore`.
- `.terraform.lock.hcl` records the exact provider version. This file **is** committed, so anyone else gets the same version.

### Step 11: Tidied and checked the code

```powershell
terraform fmt
```

This tidies the spacing. It printed nothing, meaning the files were already tidy.

```powershell
terraform validate
```

This checks the code for mistakes without connecting to Azure.

**What I saw:**

```
Success! The configuration is valid.
```

### Step 12: Previewed the changes

```powershell
terraform plan
```

This connects to Azure and shows exactly what would change, without changing anything.

**What I saw:**

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

The plan also ended with a note about using `-out`. In a team or production setting, the plan would be saved to a file with `terraform plan -out <file>` and exactly that file applied. For a lab, the standard `apply` is fine.

### Step 13: Built the resource group

```powershell
terraform apply
```

Terraform showed the plan again and asked for confirmation, so I typed `yes` and pressed **Enter**.

**What I saw:**

```
azurerm_resource_group.lab: Creating...
azurerm_resource_group.lab: Creation complete after 23s [id=/subscriptions/<subscription-id>/resourceGroups/rg-tflab01-uks]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

resource_group_location = "uksouth"
resource_group_name = "rg-tflab01-uks"
```

### Step 14: Checked it in Azure

```powershell
az group show --name rg-tflab01-uks --output table
```

**What I saw:**

```
Location    Name
----------  --------------
uksouth     rg-tflab01-uks
```

I also opened it in the portal (**Resource groups > rg-tflab01-uks > Tags**) and could see the three tags.

I then checked what Terraform was tracking:

```powershell
terraform state list
```

**What I saw:**

```
azurerm_resource_group.lab
```

A `terraform.tfstate` file had now appeared in the folder. This is the state file that `.gitignore` keeps out of GitHub.

---

## Tests I carried out

### Test 1: In-place update (a safe change)

**Goal:** see how Terraform handles a small change to something that already exists.

I opened `main.tf`:

```powershell
notepad main.tf
```

I added an `owner` tag inside the `tags` block, then saved and closed it:

```hcl
    owner       = "iM-MQ"
```

> Following along? Use your own name or username.

I previewed the change:

```powershell
terraform plan
```

**What I saw:**

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

`~` meant the existing resource group would be modified, not rebuilt. Only the new tag was being added.

I applied it, typing `yes` when asked:

```powershell
terraform apply
```

Then I checked the tags in Azure:

```powershell
az group show --name rg-tflab01-uks --query tags
```

**What I saw:**

```
{
  "environment": "lab",
  "managed_by": "terraform",
  "owner": "iM-MQ",
  "project": "terraform-azure-labs"
}
```

### Test 2: Destructive change (reviewed, not applied)

**Goal:** recognise what a dangerous change looks like in a plan.

I opened `variables.tf`:

```powershell
notepad variables.tf
```

I changed the location default from `"uksouth"` to `"ukwest"`, then saved and closed it. I previewed the change:

```powershell
terraform plan
```

**What I saw:**

```
-/+ destroy and then create replacement

  # azurerm_resource_group.lab must be replaced
      ~ location = "uksouth" -> "ukwest" # forces replacement

Plan: 1 to add, 0 to change, 1 to destroy.
```

A resource group's region cannot be changed, so Terraform would **delete it and create a new one**. The resource group was empty, but in a real environment everything inside it (VMs, databases, storage) would be deleted too. A one-word change could wipe out production, which is why I always read the plan before typing `yes`. It is the same principle as reviewing the risk and impact of an RFC before it goes to CAB.

**I did not apply this.** I opened `variables.tf` again, changed the location back to `"uksouth"`, saved it and checked:

```powershell
terraform plan
```

**What I saw:**

```
No changes. Your infrastructure matches the configuration.
```

### Test 3: Drift detection (a manual change in the portal)

**Goal:** see what happens when someone changes infrastructure by hand, bypassing the code.

I added a tag directly in the Azure portal:

1. Went to [portal.azure.com](https://portal.azure.com) and signed in.
2. Searched for **Resource groups** and opened **rg-tflab01-uks**.
3. Clicked **Tags** in the left menu.
4. Added a tag with **Name** `test` and **Value** `manual`.
5. Clicked **Apply**.

Back in PowerShell, I checked for drift:

```powershell
terraform plan
```

**What I saw:**

```
  ~ update in-place

      ~ tags = {
            "environment" = "lab"
            "managed_by"  = "terraform"
            "owner"       = "iM-MQ"
            "project"     = "terraform-azure-labs"
          - "test"        = "manual" -> null
        }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Terraform found the manual tag and planned to remove it (`-> null` means "set to nothing"), because it is not in the code. The code is the source of truth. If the tag was actually wanted, the right fix would be to add it to the code.

I applied the plan, typing `yes` when asked:

```powershell
terraform apply
```

Then I checked the tags:

```powershell
az group show --name rg-tflab01-uks --query tags
```

The `test` tag had gone, leaving only the four tags defined in the code.

---

## Clean up

Once I had finished testing, I destroyed everything, typing `yes` when asked:

```powershell
terraform destroy
```

**What I saw:**

```
Destroy complete! Resources: 1 destroyed.
```

I confirmed the resource group had gone:

```powershell
az group list --output table
```

`rg-tflab01-uks` was no longer listed. Resource groups created automatically by Azure, such as `NetworkWatcherRG`, may still appear; these are normal and free.

---

## Command reference

| Command | What it does |
|---|---|
| `winget install --id <package-id> -e` | Installs a tool on Windows |
| `terraform -version` | Shows the installed Terraform version |
| `az version` | Shows the installed Azure CLI version |
| `az login` | Signs in to Azure |
| `az account show --output table` | Shows the active subscription |
| `git init` | Makes a folder into a Git repository |
| `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` | Tells Terraform which subscription to use |
| `terraform init` | Downloads providers and prepares the folder |
| `terraform fmt` | Tidies code layout |
| `terraform validate` | Checks the code for errors |
| `terraform plan` | Previews changes without making them |
| `terraform apply` | Makes the changes, after confirmation |
| `terraform state list` | Lists resources Terraform is managing |
| `terraform destroy` | Removes everything the configuration created |
| `az group show --name <name> --query tags` | Shows a resource group's tags |
| `az group list --output table` | Lists all resource groups |

## Issues I hit and how I fixed them

| Problem | Cause | Fix |
|---|---|---|
| `The term 'terraform' is not recognized` | Terraform was not installed | `winget install --id Hashicorp.Terraform -e`, then reopened PowerShell |
| `The term 'az' is not recognized` | The Azure CLI was not installed | `winget install --id Microsoft.AzureCLI -e`, then reopened PowerShell |
| Subscription check said `NOT set` | I ran the check before running the line that sets it | Ran `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` first, then checked again |
| "Your version of Terraform is out of date" | A newer release was available | Optional. `winget upgrade --id Hashicorp.Terraform -e` found no update yet, as winget can lag behind new releases |

## What I learned

- `terraform plan` is the safety net. It shows the exact impact of a change before anything is touched, much like a change-advisory risk assessment. Any "destroy" in a plan needs careful review.
- Some changes, like a resource group's region, cannot be made in place and force a full replacement.
- The state file is Terraform's record of what it manages. It can hold sensitive data, so it is kept out of Git.
- The subscription ID is passed in as an environment variable rather than written into the code.
- The code is the source of truth. Manual changes in the portal are detected as drift and reverted.
- Resources should always be destroyed after a lab to control cost, which Terraform makes a single command.

---

## References

Official documentation I used while building and testing this lab.

| What I did | Documentation |
|---|---|
| Installed Terraform | [Install Terraform (HashiCorp)](https://developer.hashicorp.com/terraform/install) |
| Installed the Azure CLI with `winget` | [Install the Azure CLI on Windows (Microsoft Learn)](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows) |
| Signed in with `az login` and chose a subscription | [Sign in interactively using the Azure CLI (Microsoft Learn)](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively) |
| Let Terraform authenticate through my Azure CLI session | [Authenticate to Azure with a Microsoft account (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure-with-microsoft-account) |
| Declared the provider with `required_providers` | [Provider Requirements (HashiCorp)](https://developer.hashicorp.com/terraform/language/providers/requirements) |
| Pinned the provider with `~> 4.0` | [Version Constraints (HashiCorp)](https://developer.hashicorp.com/terraform/language/expressions/version-constraints) |
| Committed `.terraform.lock.hcl` | [Dependency Lock File (HashiCorp)](https://developer.hashicorp.com/terraform/language/files/dependency-lock) |
| Wrote `variables.tf` | [variable block reference (HashiCorp)](https://developer.hashicorp.com/terraform/language/block/variable) |
| Wrote `outputs.tf` | [output block reference (HashiCorp)](https://developer.hashicorp.com/terraform/language/block/output) |
| Ran `terraform init` | [terraform init command reference (HashiCorp)](https://developer.hashicorp.com/terraform/cli/commands/init) |
| Ran `terraform plan` and noted the `-out` option | [terraform plan command reference (HashiCorp)](https://developer.hashicorp.com/terraform/cli/commands/plan) |
| Kept the state file out of Git | [Manage sensitive data in your configuration (HashiCorp)](https://developer.hashicorp.com/terraform/language/manage-sensitive-data) |
| Tested drift detection | [Manage resource drift (HashiCorp tutorial)](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift) |
| Tagged the resource group | [Use tags to organize your Azure resources (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources) |
| Set up a budget alert | [Tutorial: Create and manage budgets (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets) |