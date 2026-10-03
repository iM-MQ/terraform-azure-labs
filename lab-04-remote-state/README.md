# Lab 04: Remote State in Azure Storage

## Overview

| | |
|---|---|
| **Goal** | Move Terraform state off my laptop and into Azure Storage, then prove it survives losing the local copy, locks against simultaneous changes and keeps a version history |
| **Deploys** | A state storage account (resource group, storage account, container) and a small app resource group whose state lives in it |
| **Provider** | `azurerm` v4 and `random` v3 |
| **Cost** | A storage account with a few small files, which costs very little. Actual cost checked in Azure Cost Management the following day |
| **Time** | About 1 hour |

In Labs 01 to 03, Terraform's state file lived on my laptop. That is fine for learning, but it would not work for a team. If the laptop died, Terraform would lose track of everything it built. A colleague could not work on the same infrastructure without a copy of my state file, and two people applying changes at the same time could corrupt it.

In this lab I set up **remote state**: the state file is stored in an Azure Storage account, so it is shared, locked while in use and versioned. I then migrated an existing project's local state into it and tested each of those benefits.

Below I have written up every step I took, the commands I ran and what I saw, so anyone can follow the same process.

## Architecture

```
rg-tfstate-uks                     (built by bootstrap/, state kept locally)
└── Storage account: sttfstate<random>
    └── Container: tfstate (private)
        └── lab04-app.tfstate      ← state for app/

rg-tflab04-app-uks                 (built by app/, state kept in the container above)
```

## Folder structure

```
lab-04-remote-state/
├── bootstrap/          ← Part 1: creates the storage that holds state
│   ├── providers.tf
│   ├── main.tf
│   └── outputs.tf
└── app/                ← Part 2: a project that stores its state remotely
    ├── providers.tf
    ├── backend.tf      ← tells Terraform where to keep state
    └── main.tf
```

**Why two parts?** It is a chicken-and-egg problem. The storage account has to exist before anything can store state in it, so it is built by its own small project first. That bootstrap project keeps its own state locally, which is normal.

---

## Following along?

If you want to repeat this lab yourself, a few pointers:

- I ran every command in **PowerShell**, using the terminal inside **VS Code** (**Terminal > New Terminal**).
- I created and edited the `.tf` files in **VS Code**. To create a file, right-click the folder in the VS Code file list, choose **New File**, type the name and press **Enter**.
- Each command is in its own box. Run **one line at a time**, pressing **Enter** after each.
- Boxes marked **What I saw** show my output, so you can compare. They are not commands to run.
- Code in `hcl` boxes goes **into the file** in VS Code. Save with **Ctrl + S** and check the tab shows a cross, not a dot.
- Anything in `<angle brackets>` needs replacing with your own value, **brackets included**.
- My storage account was called `sttfstate6791if`. **Yours will have a different random ending**, so use the name from your own bootstrap output wherever mine appears.

You will need the tools listed in the [main README prerequisites](../README.md#prerequisites).

---

## What was new compared with Lab 03

| Concept | What it does |
|---|---|
| **Remote backend** | Stores state in Azure Storage instead of a local file |
| **Bootstrap project** | A small separate project that builds the storage before anything can use it |
| **`random` provider** | Generates a unique ending for the storage account name, which must be unique across all of Azure |
| **State migration** | `terraform init -migrate-state` copies existing local state into the new backend |
| **State locking** | Azure places a lease on the state file while Terraform runs, blocking anyone else |
| **Blob versioning** | Every change to the state file keeps the previous version, so it can be restored |

---

## Part 1: The state storage (bootstrap)

### Step 1: Created the folders

```powershell
cd C:\terraform-labs
```

```powershell
mkdir lab-04-remote-state\bootstrap -Force
```

```powershell
mkdir lab-04-remote-state\app -Force
```

```powershell
cd lab-04-remote-state
```

### Step 2: Wrote the bootstrap provider file

I created `bootstrap\providers.tf`. This project needs a second provider, `random`, to generate part of the storage account name:

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}
```

The `random` provider has no settings, so it does not need its own `provider` block.

### Step 3: Wrote the storage resources

I created `bootstrap\main.tf`:

```hcl
# Random ending so the storage account name is unique across Azure
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Resource group for Terraform state
resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate-uks"
  location = "uksouth"

  tags = {
    project    = "terraform-azure-labs"
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}

# Storage account to hold the state files
resource "azurerm_storage_account" "state" {
  name                            = "sttfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = azurerm_resource_group.state.tags
}

# Private container inside the storage account
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
```

A state file can contain sensitive details, so I secured the storage properly:

| Setting | Why |
|---|---|
| `random_string` | Storage account names must be globally unique, 3 to 24 characters, lowercase letters and numbers only |
| `account_replication_type = "LRS"` | Three copies within one datacentre. The cheapest option, fine for a lab |
| `min_tls_version` and `https_traffic_only_enabled` | Only modern, encrypted connections are allowed |
| `allow_nested_items_to_be_public = false` | Nothing in the account can ever be made public |
| `versioning_enabled = true` | Every change to a state file keeps the previous version |
| `delete_retention_policy` (7 days) | A deleted state file can be recovered for 7 days |
| `container_access_type = "private"` | Only signed-in, authorised users can read the container |

Versioning and soft delete act as the backup and restore for the state file, the same principle as backing up a server.

### Step 4: Wrote the bootstrap outputs

I created `bootstrap\outputs.tf`, so the bootstrap prints the details the app needs:

```hcl
output "resource_group_name" {
  description = "Resource group holding the state storage account"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Storage account holding Terraform state"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Container holding the state files"
  value       = azurerm_storage_container.state.name
}
```

### Step 5: Initialised the bootstrap

```powershell
cd bootstrap
```

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

```powershell
terraform init
```

This installed both providers, `azurerm` and `random`.

```powershell
terraform fmt
```

```powershell
terraform validate
```

**What I saw:**

```
Success! The configuration is valid.
```

### Step 6: Previewed and built the storage

```powershell
terraform plan
```

**What I saw:**

```
Plan: 4 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + container_name       = "tfstate"
  + resource_group_name  = "rg-tfstate-uks"
  + storage_account_name = (known after apply)
```

The storage account name was `(known after apply)`, because the random ending had not been generated yet.

```powershell
terraform apply
```

I typed `yes` when asked. The random string was created instantly, as it is generated locally and never touches Azure. The storage account took 1 minute 33 seconds, which is normal for storage accounts.

**What I saw:**

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

container_name = "tfstate"
resource_group_name = "rg-tfstate-uks"
storage_account_name = "sttfstate6791if"
```

---

## Part 2: The app, from local to remote state

I built the app with local state first, then moved its state into Azure. This mirrors a common real-world situation: an existing project that needs moving onto shared state without rebuilding anything.

### Step 7: Created the app

```powershell
cd ..\app
```

I copied the provider file from Lab 03. `..\..` means "up two folders":

```powershell
Copy-Item ..\..\lab-03-modules\providers.tf .
```

I created `app\main.tf` with a single resource group. The app is deliberately simple, as the focus of this lab is where the state lives:

```hcl
# A small resource so the app has something to track in state
resource "azurerm_resource_group" "app" {
  name     = "rg-tflab04-app-uks"
  location = "uksouth"

  tags = {
    environment = "lab"
    project     = "terraform-azure-labs"
    managed_by  = "terraform"
    owner       = "iM-MQ"
  }
}
```

> Following along? Change `owner = "iM-MQ"` to your own name or username.

### Step 8: Built it with local state

```powershell
terraform init
```

```powershell
terraform apply
```

I typed `yes` when asked, then checked the folder:

```powershell
Get-ChildItem
```

**What I saw:**

```
Mode    Length Name
----    ------ ----
d-----         .terraform
-a----    1185 .terraform.lock.hcl
-a----     310 main.tf
-a----     194 providers.tf
-a----    1340 terraform.tfstate
```

At this point, Terraform's only record of the resource group was the 1,340-byte `terraform.tfstate` on my laptop.

### Step 9: Added the backend

I created `app\backend.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-uks"
    storage_account_name = "sttfstate6791if"
    container_name       = "tfstate"
    key                  = "lab04-app.tfstate"
  }
}
```

> Following along? Replace `sttfstate6791if` with the `storage_account_name` from your own bootstrap output.

| Setting | Meaning |
|---|---|
| `resource_group_name` | The resource group holding the storage account |
| `storage_account_name` | The storage account, including its random ending |
| `container_name` | The private container |
| `key` | The file name the state is saved as. Each project uses its own key, so many projects can share one storage account |

Two things I noted:

- **Backend blocks cannot use variables.** Terraform reads the backend before anything else, so the values have to be written in directly.
- **No passwords are stored.** Terraform authenticates using the `az login` session and the `ARM_SUBSCRIPTION_ID` setting.

### Step 10: Migrated the state into Azure

Changing the backend means running `init` again. The `-migrate-state` option tells Terraform to copy the existing state across:

```powershell
terraform init -migrate-state
```

**What I saw:**

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "azurerm" backend. No existing state was found in the newly
  configured "azurerm" backend. Do you want to copy this state to the new "azurerm"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.
```

Answering `no` here would have started Terraform with an empty state. It would have forgotten the resource group and tried to create it again, so reading the prompt properly matters.

### Step 11: Confirmed the state was in Azure

I listed the files in the container:

```powershell
az storage blob list --account-name sttfstate6791if --container-name tfstate --auth-mode key --query "[].{Name:name, Size:properties.contentLength}" --output table
```

**What I saw:**

```
Name               Size
-----------------  ------
lab04-app.tfstate  1340
```

The size matched the local file exactly, so the whole state had copied across.

The Azure CLI also printed a message saying no credentials were provided and it would query the account key. That is expected with `--auth-mode key`: it looks up the storage key using my signed-in session.

I then checked the local folder:

```powershell
Get-ChildItem
```

**What I saw:**

```
Length Name
------ ----
     0 terraform.tfstate
  1340 terraform.tfstate.backup
```

Terraform had emptied the local state file and kept a `.backup` copy of the old local state, in case the migration had gone wrong. Both are excluded from Git by `.gitignore`.

Finally, I checked Terraform could still see the resource group:

```powershell
terraform plan
```

**What I saw:**

```
No changes. Your infrastructure matches the configuration.
```

Terraform read its state from Azure and found everything matched.

---

## Tests I carried out

### Test 1: Losing the local copy

**Goal:** simulate a lost or replaced laptop, and prove Terraform still knows what it manages.

I deleted both local state files:

```powershell
Remove-Item terraform.tfstate
```

```powershell
Remove-Item terraform.tfstate.backup
```

```powershell
Get-ChildItem
```

No `.tfstate` files were left. I then ran:

```powershell
terraform plan
```

**What I saw:**

```
No changes. Your infrastructure matches the configuration.
```

With no state on the laptop at all, Terraform still knew about the resource group, because it reads its state from the storage account. This is what lets a colleague pick up the same project on a different machine.

### Test 2: State locking

**Goal:** prove two people cannot change the same infrastructure at the same time.

I used two VS Code terminals to act as two people.

**Person 1:** I added a tag to `app\main.tf`, inside the `tags` block:

```hcl
    lock_test   = "true"
```

Then I ran:

```powershell
terraform apply
```

I left it waiting at `Enter a value:` without answering. While it waits, Terraform holds the lock.

**Person 2:** I opened a second terminal with the **+** icon on the terminal panel. A new terminal is a new session, so I set it up first:

```powershell
cd C:\terraform-labs\lab-04-remote-state\app
```

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

```powershell
terraform plan
```

**What I saw** (the `Who` line, which shows the machine and user, is removed):

```
│ Error: Error acquiring the state lock
│
│ Error message: state blob is already locked
│ Lock Info:
│   ID:        4cb28201-11d5-3496-7d17-477b29d79dbc
│   Path:      tfstate/lab04-app.tfstate
│   Operation: OperationTypeApply
│   Version:   1.16.2
│   Created:   2026-09-30 21:19:19 UTC
│
│ Terraform acquires a state lock to protect the state from being written
│ by multiple users at the same time. Please resolve the issue above and try
│ again. For most commands, you can disable locking with the "-lock=false"
│ flag, but this is not recommended.
```

Person 2 was blocked, and the lock information showed who held it, what they were doing and when they started. The message also mentions `-lock=false`. Bypassing the lock is how state files get corrupted, so it should almost never be used.

**Releasing the lock:** I switched back to Person 1 and typed `yes`:

```
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Terraform released the lock when the apply finished. Back in Person 2's terminal:

```powershell
terraform plan
```

**What I saw:**

```
No changes. Your infrastructure matches the configuration.
```

Person 2 could run straight away and could already see Person 1's change, because both read the same state file.

### Test 3: State version history

**Goal:** confirm versioning was keeping previous copies of the state file.

```powershell
az storage blob list --account-name sttfstate6791if --container-name tfstate --auth-mode key --include v --query "[].{Name:name, Version:versionId, Current:isCurrentVersion, Size:properties.contentLength}" --output table
```

`--include v` includes previous versions, not just the current file.

**What I saw** (shortened; there were 16 versions in total):

```
Name               Version                       Size    Current
-----------------  ----------------------------  ------  ---------
lab04-app.tfstate  2026-09-30T21:13:30.7035991Z  0
lab04-app.tfstate  2026-09-30T21:13:31.0968787Z  181
lab04-app.tfstate  2026-09-30T21:13:44.5007783Z  1340
...
lab04-app.tfstate  2026-09-30T21:19:20.2331272Z  1340
lab04-app.tfstate  2026-09-30T21:23:36.2268588Z  1375
...
lab04-app.tfstate  2026-09-30T21:24:02.1812514Z  1375    True
```

The sizes told the story of the lab:

| Size | What happened |
|---|---|
| 0 | `init -migrate-state` created an empty placeholder |
| 181 | Terraform wrote an empty state skeleton |
| 1,340 | My local state was copied in |
| 1,340 (several) | Each `plan` and `apply` locked and unlocked the file, and each lock change saved a new version |
| 1,375 | Person 1's apply added the `lock_test` tag |

There were more versions than I expected. Terraform locks the state by placing a lease on the blob and recording who holds it in the blob's metadata, and each metadata change creates a new version. In a busy team, a storage lifecycle rule would normally be added to clear out old versions after a set number of days.

If the state file were ever corrupted or overwritten, an earlier version could be restored from this history.

---

## Clean up

**The order matters.** The app's state lives inside the storage account, so the app has to be destroyed first, while its state is still there to read. Destroying the storage first would delete the app's state, and Terraform would lose track of the app's resources.

**1. Destroyed the app:**

```powershell
terraform destroy
```

I typed `yes` when asked.

```
Destroy complete! Resources: 1 destroyed.
```

I checked the state file:

```powershell
az storage blob list --account-name sttfstate6791if --container-name tfstate --auth-mode key --query "[].{Name:name, Size:properties.contentLength}" --output table
```

```
Name               Size
-----------------  ------
lab04-app.tfstate  181
```

Terraform does not delete the state file on destroy. It shrank back to the 181-byte empty skeleton, meaning "this project manages nothing".

**2. Destroyed the state storage.** The bootstrap's own state was still local, which is why I kept it safe until now:

```powershell
cd ..\bootstrap
```

```powershell
terraform destroy
```

I typed `yes` when asked.

```
Destroy complete! Resources: 4 destroyed.
```

This removed the container, storage account, resource group and random string, along with every version of the state file.

---

## Dealing with a stuck lock

If Terraform crashes, loses its connection or is closed partway through an apply, it may not release the lock. Everyone is then blocked with the same `Error acquiring the state lock` message, even though nobody is actually running Terraform.

The fix is to release the lock manually, using the ID from the error message:

```powershell
terraform force-unlock <lock-id>
```

For example, with the lock from Test 2:

```powershell
terraform force-unlock 4cb28201-11d5-3496-7d17-477b29d79dbc
```

Terraform asks for confirmation before releasing it.

**Only use this when you are certain nobody else is running Terraform on that project.** Check the `Who`, `Operation` and `Created` details in the error first. If a colleague's apply is genuinely still running, force-unlocking lets two changes run at once, which is exactly what the lock exists to prevent. In a team, I would confirm with the person named in the lock before releasing it.

I did not need to run this in the lab, as the lock released normally.

---

## Command reference

| Command | What it does |
|---|---|
| `terraform init` | Downloads providers and connects to the backend |
| `terraform init -migrate-state` | Copies existing state into a newly configured backend |
| `terraform plan` / `apply` / `destroy` | As before, but now reading and writing state in Azure |
| `terraform force-unlock <lock-id>` | Releases a stuck lock. Only when nobody else is running Terraform |
| `az storage blob list ... --auth-mode key` | Lists files in the state container |
| `az storage blob list ... --include v` | Includes previous versions of each file |
| `Remove-Item <file>` | Deletes a file |
| `..\..` | Refers to the folder two levels up |

## When to run `terraform init` (updated)

| Change | Need `init`? |
|---|---|
| Adding a module block | Yes |
| Adding or changing a provider | Yes |
| **Adding or changing a backend** | **Yes, with `-migrate-state` to keep existing state** |
| Removing a module block | No |
| Changing values such as names, tags or IP ranges | No |

## Things I noticed along the way

| Observation | Explanation |
|---|---|
| The storage account took 1 minute 33 seconds to create | Normal for storage accounts, which take longer than networking resources |
| The Azure CLI warned that no credentials were provided | Expected with `--auth-mode key`. It fetches the storage key using the signed-in session |
| The local state file was 0 bytes after migrating, with a `.backup` file alongside | Terraform empties the local file and keeps a safety copy |
| There were 16 versions of the state file | Every lock and unlock changes the blob's metadata, and each change creates a version |
| The bootstrap's own state stayed local | The storage it creates cannot hold its own state until it exists |

## What I learned

- Local state is a single point of failure. Remote state means losing a laptop does not mean losing track of the infrastructure, which I proved by deleting the local files completely.
- State locking stops two people changing the same infrastructure at once. The lock message says who holds it, what they are doing and when they started, which makes it easy to follow up with the right person.
- A stuck lock can be released with `terraform force-unlock`, but only after confirming nobody is actually running Terraform.
- Existing projects can be moved onto remote state with `terraform init -migrate-state` without rebuilding anything, as long as the migration prompt is answered correctly.
- Versioning and soft delete on the storage account act as backups for the state file.
- Clean-up order matters when one project depends on another. The app had to be destroyed before the storage holding its state.
- The bootstrap pattern solves the chicken-and-egg problem of needing somewhere to store state before that storage exists.

---

## References

Official documentation I used while building and testing this lab.

| What I did | Documentation |
|---|---|
| Stored Terraform state in an Azure Storage account and blob container | [Store Terraform state in Azure Storage](https://learn.microsoft.com/en-us/azure/terraform/terraform-backend) |
| Configured the `backend "azurerm"` block | [Backend Type: azurerm](https://developer.hashicorp.com/terraform/language/backend/azurerm) |
| Moved existing local state into the new backend | [Backend block configuration overview](https://developer.hashicorp.com/terraform/language/backend) |
| Ran `terraform init -migrate-state` | [terraform init](https://developer.hashicorp.com/terraform/cli/commands/init) |
| Tested state locking with two terminals | [State Locking](https://developer.hashicorp.com/terraform/language/state/locking) |
| Cleared a stuck lock with its lock ID | [terraform force-unlock](https://developer.hashicorp.com/terraform/cli/commands/force-unlock) |
| Enabled blob versioning to protect the state file | [Blob versioning in Azure Storage](https://learn.microsoft.com/azure/storage/blobs/versioning-overview) |