# Lab 03: Reusable Modules

## Overview

| | |
|---|---|
| **Goal** | Turn the network from Lab 02 into a reusable module, then use it to build separate dev and test networks from the same code |
| **Deploys** | One resource group and two networks, each with a VNet, two subnets, two NSGs and their associations (15 resources) |
| **Provider** | `azurerm` v4 |
| **Cost** | Free (virtual networks, subnets and NSGs have no charge on their own) |
| **Time** | About 1 hour |

In Lab 02 I wrote the network directly into `main.tf`. That works for one network, but if I needed another for a different environment I would have to copy and paste the whole thing and change every name and IP range by hand, which is exactly where mistakes creep in.

In this lab I packaged the network as a **module**: a reusable building block that takes a few inputs and builds the full network from them. I then used it twice to build dev and test networks, added validation so bad input is rejected before anything reaches Azure, and tested how easily it scales to a third environment.

Below I have written up every step I took, the commands I ran and what I saw, so anyone can follow the same process.

## Architecture

```
Resource group: rg-tflab03-uks
├── vnet-dev  (10.20.0.0/16)
│   ├── snet-web (10.20.1.0/24) ── nsg-dev-web: allow HTTPS (443) from the internet
│   └── snet-app (10.20.2.0/24) ── nsg-dev-app: allow TCP 8080 from snet-web only, deny other VNet traffic
└── vnet-test (10.30.0.0/16)
    ├── snet-web (10.30.1.0/24) ── nsg-test-web: allow HTTPS (443) from the internet
    └── snet-app (10.30.2.0/24) ── nsg-test-app: allow TCP 8080 from snet-web only, deny other VNet traffic
```

Both networks are built from the **same** module code. The address ranges do not overlap, so they could be connected later if needed.

## Folder structure

```
lab-03-modules/
├── main.tf              ← uses the module twice (dev and test)
├── outputs.tf           ← summary of both networks
├── providers.tf
└── modules/
    └── network/         ← the reusable module
        ├── main.tf      ← the network resources
        ├── variables.tf ← the module's inputs, with validation
        └── outputs.tf   ← what the module hands back
```

---

## Following along?

If you want to repeat this lab yourself, a few pointers:

- I ran every command in **PowerShell**, using the terminal inside **VS Code** (**Terminal > New Terminal**).
- I created and edited the `.tf` files in **VS Code**. To create a file, right-click the folder in the VS Code file list, choose **New File**, type the name and press **Enter**.
- Each command is in its own box. Run **one line at a time**, pressing **Enter** after each.
- Boxes marked **What I saw** show my output, so you can compare. They are not commands to run.
- Code in `hcl` boxes is Terraform code. Paste it **into the file** in VS Code and save with **Ctrl + S**. Do not paste it into PowerShell.
- When Terraform asks `Enter a value:`, type the full word `yes` and press **Enter**.

You will need the tools listed in the [main README prerequisites](../README.md#prerequisites). This lab builds on [Lab 02](../lab-02-virtual-network), so it is worth doing that first.

---

## What was new compared with Lab 02

| Concept | What it does |
|---|---|
| **Modules** | Package a set of resources so they can be reused with different inputs |
| **Required variables** | Module inputs with no default, so whoever uses the module must supply them |
| **Validation** | Rules that reject bad input with a clear message before anything reaches Azure |
| **String interpolation** | `"vnet-${var.name_prefix}"` builds names from inputs, so each use gets its own names |
| **Module outputs** | How a module hands information, such as subnet IDs, back to the code that used it |
| **`locals`** | Named values set once and reused, like the location and shared tags |
| **`merge()`** | Combines two sets of tags: the shared ones plus an `environment` tag per network |

---

## How I built it

### Step 1: Created the folders

I moved into my labs folder and created the lab folder:

```powershell
cd C:\terraform-labs
```

```powershell
mkdir lab-03-modules
```

```powershell
cd lab-03-modules
```

I then created the folder for the module. `-Force` creates both levels (`modules` and `network` inside it) in one go:

```powershell
mkdir modules\network -Force
```

I copied the provider file from Lab 02, as every lab uses the same settings:

```powershell
Copy-Item ..\lab-02-virtual-network\providers.tf .
```

I checked the layout:

```powershell
Get-ChildItem -Recurse | Select-Object FullName
```

**What I saw:**

```
C:\terraform-labs\lab-03-modules\modules
C:\terraform-labs\lab-03-modules\providers.tf
C:\terraform-labs\lab-03-modules\modules\network
```

### Step 2: Wrote the module's inputs

I created `variables.tf` inside **`modules\network`**. A module's variables work like a form that whoever uses it has to fill in. Most have no default, so they must be supplied, and two have validation rules:

```hcl
variable "name_prefix" {
  description = "Short name for this network, used in resource names (e.g. dev, test)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.name_prefix))
    error_message = "name_prefix must be 2 to 10 lowercase letters or numbers, e.g. dev or test."
  }
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to put the network in"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.address_space : can(cidrnetmask(cidr))])
    error_message = "Every address_space entry must be a valid CIDR range, e.g. 10.20.0.0/16."
  }
}

variable "web_subnet_prefix" {
  description = "Address range for the web subnet"
  type        = string
}

variable "app_subnet_prefix" {
  description = "Address range for the app subnet"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
```

- `name_prefix` must be 2 to 10 lowercase letters or numbers, so it is always safe to use in Azure resource names.
- Every `address_space` entry must be a real CIDR range. `cidrnetmask()` fails on anything invalid, and `alltrue()` only passes if every entry in the list is valid.
- `tags` defaults to `{}` (no tags), so it is optional.

### Step 3: Wrote the module's resources

I created `main.tf` inside **`modules\network`**. It is the same design as Lab 02, with the app tier locked down from the start, but every name and range now comes from the inputs:

```hcl
# Virtual network
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# Subnet: web tier
resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.web_subnet_prefix]
}

# Subnet: app tier
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.app_subnet_prefix]
}

# NSG for the web tier: HTTPS from the internet
resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.name_prefix}-web"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# NSG for the app tier: only the web tier on 8080
resource "azurerm_network_security_group" "app" {
  name                = "nsg-${var.name_prefix}-app"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-Web-To-App-8080"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.web_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-VNet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# Attach the NSGs to their subnets
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

- `"vnet-${var.name_prefix}"` inserts the input into the name, so `dev` gives `vnet-dev` and `test` gives `vnet-test`.
- The module does **not** create a resource group. It puts the network into whichever resource group it is given, which keeps the module focused on one job.
- The main VNet is labelled `this`, a common convention for a module's primary resource.

### Step 4: Wrote the module's outputs

I created `outputs.tf` inside **`modules\network`**, so the module hands back useful information, such as the subnet IDs, that other code would need to place a VM or container in the network:

```hcl
output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "IDs of the web and app subnets"
  value = {
    web = azurerm_subnet.web.id
    app = azurerm_subnet.app.id
  }
}

output "nsg_names" {
  description = "Names of the web and app NSGs"
  value = {
    web = azurerm_network_security_group.web.name
    app = azurerm_network_security_group.app.name
  }
}
```

### Step 5: Used the module twice

In the **main lab folder** (not `modules\network`), I created `main.tf`. It creates the resource group, then uses the module twice with different inputs:

```hcl
# Values used in more than one place
locals {
  location = "uksouth"

  common_tags = {
    project    = "terraform-azure-labs"
    managed_by = "terraform"
    owner      = "iM-MQ"
  }
}

# Resource group for both networks
resource "azurerm_resource_group" "lab" {
  name     = "rg-tflab03-uks"
  location = local.location
  tags     = local.common_tags
}

# Dev network, built from the module
module "network_dev" {
  source = "./modules/network"

  name_prefix         = "dev"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/16"]
  web_subnet_prefix   = "10.20.1.0/24"
  app_subnet_prefix   = "10.20.2.0/24"
  tags                = merge(local.common_tags, { environment = "dev" })
}

# Test network, built from the same module
module "network_test" {
  source = "./modules/network"

  name_prefix         = "test"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
  web_subnet_prefix   = "10.30.1.0/24"
  app_subnet_prefix   = "10.30.2.0/24"
  tags                = merge(local.common_tags, { environment = "test" })
}
```

> Following along? Change `owner = "iM-MQ"` to your own name or username.

- `source = "./modules/network"` tells Terraform where the module lives.
- Each line inside a `module` block fills in one of the module's variables.
- The two blocks only differ in name and address ranges. That is the whole point: one piece of code, two networks.

### Step 6: Wrote the root outputs

In the main lab folder, I created `outputs.tf` to summarise both networks using the module's outputs:

```hcl
output "resource_group_name" {
  description = "Resource group holding both networks"
  value       = azurerm_resource_group.lab.name
}

output "dev_network" {
  description = "Summary of the dev network"
  value = {
    vnet          = module.network_dev.vnet_name
    address_space = module.network_dev.address_space
    nsgs          = module.network_dev.nsg_names
  }
}

output "test_network" {
  description = "Summary of the test network"
  value = {
    vnet          = module.network_test.vnet_name
    address_space = module.network_test.address_space
    nsgs          = module.network_test.nsg_names
  }
}
```

`module.network_dev.vnet_name` means "from the module I called `network_dev`, give me its `vnet_name` output".

### Step 7: Told Terraform which subscription to use

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

This prints nothing when it works. It needs running again in every new PowerShell window.

### Step 8: Initialised Terraform

```powershell
terraform init
```

My first attempt failed, which is covered in the [debugging write-up](#debugging-write-up-powershell-text-inside-a-terraform-file) below. Once fixed, I saw:

```
Initializing modules...
- network_dev in modules\network
- network_test in modules\network

Initializing provider plugins...
- Installed hashicorp/azurerm v4.81.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

The new `Initializing modules...` section shows Terraform found the module and registered both uses of it.

### Step 9: Tidied and checked the code

With code now in two folders, `fmt` needs `-recursive` to include the module folder:

```powershell
terraform fmt -recursive
```

```powershell
terraform validate
```

**What I saw:**

```
Success! The configuration is valid.
```

### Step 10: Previewed the changes

```powershell
terraform plan
```

Resources built by a module show their full address, including the module name:

```
# module.network_dev.azurerm_virtual_network.this will be created
# module.network_test.azurerm_virtual_network.this will be created
```

**What I saw** (end of the plan):

```
Plan: 15 to add, 0 to change, 0 to destroy.
```

That is 7 resources per network (VNet, 2 subnets, 2 NSGs, 2 associations), twice, plus the resource group.

The plan also showed the module adapting its security rules to each network. The dev app NSG allowed 8080 from `10.20.1.0/24` and the test one from `10.30.1.0/24`, each using its own web subnet, without the rule being written twice.

### Step 11: Built both networks

```powershell
terraform apply
```

I typed `yes` when asked. Terraform built both networks at the same time, because neither depends on the other.

**What I saw:**

```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

dev_network = {
  "address_space" = toset([
    "10.20.0.0/16",
  ])
  "nsgs" = {
    "app" = "nsg-dev-app"
    "web" = "nsg-dev-web"
  }
  "vnet" = "vnet-dev"
}
resource_group_name = "rg-tflab03-uks"
test_network = {
  "address_space" = toset([
    "10.30.0.0/16",
  ])
  "nsgs" = {
    "app" = "nsg-test-app"
    "web" = "nsg-test-web"
  }
  "vnet" = "vnet-test"
}
```

### Step 12: Checked it in Azure

I listed the networks in the resource group:

```powershell
az network vnet list --resource-group rg-tflab03-uks --query "[].{Name:name, Range:addressSpace.addressPrefixes[0]}" --output table
```

**What I saw:**

```
Name       Range
---------  ------------
vnet-dev   10.20.0.0/16
vnet-test  10.30.0.0/16
```

I then checked how Terraform tracks the resources:

```powershell
terraform state list
```

**What I saw** (15 lines, shortened here):

```
azurerm_resource_group.lab
module.network_dev.azurerm_network_security_group.app
module.network_dev.azurerm_network_security_group.web
...
module.network_test.azurerm_virtual_network.this
```

Each resource is prefixed with the module it came from, which is how Terraform keeps the two networks apart even though they come from the same code.

---

## Tests I carried out

### Test 1: Invalid address range

**Goal:** check the validation catches a bad CIDR range before anything reaches Azure.

In the root `main.tf`, I changed the test network's address range to an invalid mask:

```hcl
  address_space       = ["10.30.0.0/99"]
```

```powershell
terraform plan
```

**What I saw:**

```
│ Error: Invalid value for variable
│
│   on main.tf line 39, in module "network_test":
│   39:   address_space       = ["10.30.0.0/99"]
│
│ Every address_space entry must be a valid CIDR range, e.g. 10.20.0.0/16.
│
│ This was checked by the validation rule at modules\network\variables.tf:25,3-13.
```

The error pointed at the exact line, showed my own message and named the rule that caught it. Nothing reached Azure.

### Test 2: Invalid name

**Goal:** check the name validation.

I set the address range back to `10.30.0.0/16`, then changed the name to use capitals and an underscore:

```hcl
  name_prefix         = "Test_Env"
```

```powershell
terraform plan
```

**What I saw:**

```
│ Error: Invalid value for variable
│
│   on main.tf line 36, in module "network_test":
│   36:   name_prefix         = "Test_Env"
│
│ name_prefix must be 2 to 10 lowercase letters or numbers, e.g. dev or test.
│
│ This was checked by the validation rule at modules\network\variables.tf:5,3-13.
```

I changed the name back to `test` and confirmed nothing had changed:

```powershell
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

### Test 3: Adding a third environment (plan only)

**Goal:** see how easily the module scales.

I added a production network to the bottom of the root `main.tf`:

```hcl
# Prod network, built from the same module
module "network_prod" {
  source = "./modules/network"

  name_prefix         = "prod"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.40.0.0/16"]
  web_subnet_prefix   = "10.40.1.0/24"
  app_subnet_prefix   = "10.40.2.0/24"
  tags                = merge(local.common_tags, { environment = "prod" })
}
```

A new module block needs registering, so I ran `init` first:

```powershell
terraform init
```

```powershell
terraform plan
```

**What I saw:**

```
Plan: 7 to add, 0 to change, 0 to destroy.
```

A complete production network with locked-down NSGs from 12 lines of code, with dev and test untouched. Without the module, it would have meant copying around 90 lines and changing every name and range by hand.

This was a plan-only test, so I removed the block again and confirmed `terraform plan` showed `No changes`. Removing a module block does not need `init`, as there is nothing new to register.

---

## Clean up

```powershell
terraform destroy
```

I typed `yes` when asked. Both networks were removed in parallel, each in reverse dependency order, with the resource group last.

```
Destroy complete! Resources: 15 destroyed.
```

I confirmed the resource group had gone:

```powershell
az group list --output table
```

`rg-tflab03-uks` was no longer listed.

---

## Debugging write-up: PowerShell text inside a Terraform file

**Symptom**

VS Code showed a **7** next to `modules\network\main.tf`, and the Problems panel (**Ctrl + Shift + M**) listed errors on line 1 and the last line. After I thought I had fixed it, `terraform init` still failed with errors including:

```
│ Error: Unsupported block type
│
│   on modules\network\main.tf line 1:
│    1: Set-Content modules\network\main.tf @'
│
│ Blocks of type "Set-Content" are not expected here.
```

**Investigation**

The error message named `Set-Content`, which is a PowerShell command, not Terraform. Line 1 of the file contained the start of a PowerShell command, and the last line (89) contained its closing `'@`. The Terraform code in between was correct.

**Root cause**

Two things combined:

1. I had pasted a full PowerShell command, including its wrapper lines, into the file in VS Code, rather than running it in the terminal. The wrapper lines became part of the file.
2. I removed the lines in VS Code, which cleared the Problems panel, but the change was not saved to disk. Terraform reads the file from disk, so it still saw the old version.

**Fix**

I closed the file in VS Code without saving, then removed the first and last lines from PowerShell:

```powershell
$lines = Get-Content modules\network\main.tf
```

```powershell
$lines[1..($lines.Count - 2)] | Set-Content modules\network\main.tf
```

I checked both ends of the file:

```powershell
Get-Content modules\network\main.tf -TotalCount 1
```

```
# Virtual network
```

```powershell
Get-Content modules\network\main.tf -Tail 2
```

```
  network_security_group_id = azurerm_network_security_group.app.id
}
```

`terraform init` then succeeded.

**Prevention**

- Terraform code goes into `.tf` files. PowerShell commands go into the terminal. I now keep the two clearly separate.
- An unsaved tab in VS Code shows a dot instead of a cross. I check for it before running Terraform.
- If the Problems panel is clear but Terraform still errors, the file on disk is the one to check.

---

## Command reference

| Command | What it does |
|---|---|
| `mkdir modules\network -Force` | Creates a folder and any missing parent folders |
| `Get-ChildItem -Recurse` | Lists files and folders, including subfolders |
| `terraform init` | Registers modules and downloads providers. Needed after adding a module |
| `terraform fmt -recursive` | Tidies code in this folder and all subfolders |
| `terraform validate` | Checks the whole configuration, including modules |
| `terraform plan` | Previews changes and runs validation rules |
| `terraform apply` | Builds or updates the infrastructure |
| `terraform state list` | Lists managed resources, including their module path |
| `terraform destroy` | Removes everything |
| `az network vnet list ...` | Lists VNets and their address ranges |
| `Get-Content <file> -TotalCount 1` | Shows the first line of a file |
| `Get-Content <file> -Tail 2` | Shows the last two lines of a file |

## When to run `terraform init`

| Change | Need `init`? |
|---|---|
| Adding a module block | Yes |
| Changing a module's `source` | Yes |
| Adding or changing a provider or its version | Yes |
| Changing the backend (where state is stored) | Yes |
| Removing a module block | No |
| Changing values such as names or IP ranges | No |

Running `init` when it is not needed is harmless, and Terraform tells you if you skip it when it is needed.

## What I learned

- Modules turn a design into a reusable building block. Adding a whole new environment took 12 lines instead of around 90.
- A module's inputs define its contract. Required variables make sure whoever uses it supplies what it needs, and validation catches mistakes before they reach Azure, with clear messages that point at the exact line.
- Building names from inputs (`"vnet-${var.name_prefix}"`) is what lets one module create many differently named resources.
- Module outputs are how modules plug into each other. The subnet IDs from this module are what a VM or container would need to be placed in the network.
- Resources inside modules have their own address in state (`module.network_dev...`), which keeps each use separate.
- When a fix does not seem to work, check the change was actually saved. The file on disk is what Terraform reads, not what the editor shows.

---

## References

Official documentation I used while building and testing this lab.

| What I did | Documentation |
|---|---|
| Built a local module and called it from the root configuration | [Build and use a local module](https://developer.hashicorp.com/terraform/tutorials/modules/module-create) |
| Used `module` blocks with local `./modules/...` sources | [module block reference](https://developer.hashicorp.com/terraform/language/block/module) |
| Added validation rules to module inputs | [variable block reference](https://developer.hashicorp.com/terraform/language/block/variable) |
| Validated CIDR ranges | [cidrnetmask function](https://developer.hashicorp.com/terraform/language/functions/cidrnetmask) |
| Checked every subnet in a list passed validation | [alltrue function](https://developer.hashicorp.com/terraform/language/functions/alltrue) |
| Merged default tags with extra tags | [merge function](https://developer.hashicorp.com/terraform/language/functions/merge) |
| Built names and tags once using locals | [locals block reference](https://developer.hashicorp.com/terraform/language/block/locals) |
| Built resource names with `${}` interpolation | [Strings and Templates](https://developer.hashicorp.com/terraform/language/expressions/strings) |
| Re-ran init to install the new modules | [terraform init](https://developer.hashicorp.com/terraform/cli/commands/init) |
| Formatted the module folders | [terraform fmt](https://developer.hashicorp.com/terraform/cli/commands/fmt) |
| Listed resources by their module address | [terraform state list](https://developer.hashicorp.com/terraform/cli/commands/state/list) |
| Checked the VNets in Azure | [az network vnet](https://learn.microsoft.com/en-us/cli/azure/network/vnet) |