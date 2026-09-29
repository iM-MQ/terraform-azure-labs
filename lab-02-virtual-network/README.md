# Lab 02: Virtual Network, Subnets and Network Security Groups

## Overview

| | |
|---|---|
| **Goal** | Build a segmented two-tier network in Azure using Terraform, and control traffic between the tiers with NSGs |
| **Deploys** | Resource group, virtual network, two subnets, two NSGs and their subnet associations (8 resources) |
| **Provider** | `azurerm` v4 |
| **Cost** | Free (virtual networks, subnets and NSGs have no charge on their own) |
| **Time** | About 45 minutes |

In this lab I built a small network laid out the way I would expect to see a real environment: a web tier that accepts HTTPS from the internet, and an app tier that only accepts traffic from the web tier. Coming from a networking background (CCNA, VLANs, ACLs), I wanted to see how the same segmentation ideas translate into Azure and into code.

## Architecture

```
Resource group: rg-tflab02-uks
└── Virtual network: vnet-tflab02-uks (10.10.0.0/16)
    ├── snet-web (10.10.1.0/24)  ── nsg-web: allow HTTPS (443) from the internet
    └── snet-app (10.10.2.0/24)  ── nsg-app: allow TCP 8080 from snet-web only, deny all other VNet traffic
```

---

## How to use this guide

- **Where to run commands:** every command is run in **Windows PowerShell**. To open it, click **Start**, type `PowerShell` and select **Windows PowerShell**.
- **One line at a time:** each command is in its own box. Copy **one line**, paste it into PowerShell, press **Enter**, and wait for it to finish before running the next.
- **Fill in the blanks:** anything shown in `<angle brackets>` must be replaced with your own value, **including removing the brackets**. For example, `<your-folder-path>` becomes `C:\terraform-labs`.
- **Expected output:** boxes labelled **Expected output** show what you should see. They are **not** commands to run.
- **Terraform code** (shown in `hcl` boxes) goes **inside `.tf` files**, not into PowerShell.
- **Typing `yes`:** when Terraform asks `Enter a value:`, type the full word `yes` and press **Enter**. Anything else cancels.

## Before you start

You will need the tools listed in the [main README prerequisites](../README.md#prerequisites):

- An Azure subscription
- Terraform (1.9 or later)
- Azure CLI
- A text editor (Notepad is fine; VS Code is better)

If you have not completed [Lab 01](../lab-01-resource-group), it is worth doing first, as it explains the basic Terraform workflow used here.

---

## Files in this lab

| File | Purpose |
|---|---|
| `providers.tf` | Azure provider and version constraints |
| `variables.tf` | Region, resource group name, address ranges and a shared map of tags |
| `main.tf` | The network, subnets, NSGs and associations |
| `outputs.tf` | A summary of the network after it is built |
| `.terraform.lock.hcl` | Created automatically by `terraform init`. Records the exact provider version used |

## What was new in this lab

**Variable types.** Lab 01 only used strings. Here I used:
- `list(string)` for the VNet address space, because Azure expects a list even when there is only one range.
- `map(string)` for tags, so I could define them once and apply them to every resource with `tags = var.tags`.

**Implicit dependencies.** Rather than typing names into every resource, each one references the resource it belongs to:

```hcl
resource_group_name  = azurerm_resource_group.lab.name
virtual_network_name = azurerm_virtual_network.lab.name
```

Terraform reads these references and works out the build order itself. I never had to tell it what to create first.

**NSG associations.** Linking an NSG to a subnet is its own resource in Terraform (`azurerm_subnet_network_security_group_association`), which uses the IDs of both the subnet and the NSG.

---

## Walkthrough

### Step 1: Go to your labs folder

Open **Windows PowerShell**, then run:

```powershell
cd C:\terraform-labs
```

**What it does:** moves PowerShell into the folder that holds all the labs.

> If your labs folder is somewhere else, use `cd <your-folder-path>` instead, replacing `<your-folder-path>` with the full path to your folder.

### Step 2: Create the lab folder

Run each line separately:

```powershell
mkdir lab-02-virtual-network
```

**What it does:** creates a new folder for this lab.

```powershell
cd lab-02-virtual-network
```

**What it does:** moves into the new folder. Your prompt should now end in `\lab-02-virtual-network>`.

### Step 3: Copy the provider file from Lab 01

```powershell
Copy-Item ..\lab-01-resource-group\providers.tf .
```

**What it does:** copies `providers.tf` from the Lab 01 folder into this one. `..` means "the folder above this one", and the final `.` means "into this folder". Every lab uses the same provider settings, so there is no need to write it again.

Check it copied:

```powershell
Get-Content providers.tf
```

**Expected output:**

```
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

> **Skipped Lab 01?** Create the file yourself instead: run `notepad providers.tf`, click **Yes** to create it, paste the code from the expected output above, then save and close.

### Step 4: Create `variables.tf`

```powershell
notepad variables.tf
```

**What it does:** opens Notepad with a new file called `variables.tf`. Click **Yes** when asked to create it.

Paste in the following code, then **save** (Ctrl + S) and **close** Notepad:

```hcl
variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-tflab02-uks"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "web_subnet_prefix" {
  description = "Address range for the web subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "app_subnet_prefix" {
  description = "Address range for the app subnet"
  type        = string
  default     = "10.10.2.0/24"
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    environment = "lab"
    project     = "terraform-azure-labs"
    managed_by  = "terraform"
    owner       = "<your-name>"
  }
}
```

> Replace `<your-name>` with your own name or username, for example `owner = "iM-MQ"`.

### Step 5: Create `main.tf`

```powershell
notepad main.tf
```

Click **Yes** to create the file, paste in the following, then save and close:

```hcl
# Resource group
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual network
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-tflab02-uks"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnet: web tier
resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.web_subnet_prefix]
}

# Subnet: app tier
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.app_subnet_prefix]
}

# Network security group for the web tier
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
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

# Attach the NSG to the web subnet
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}
```

> The file in this repo also includes `nsg-app`, which is added later in [Test 1](#test-1-locking-down-the-app-tier). If you are following along from scratch, start with the code above and add `nsg-app` when you reach Test 1.

### Step 6: Create `outputs.tf`

```powershell
notepad outputs.tf
```

Click **Yes**, paste in the following, then save and close:

```hcl
output "resource_group_name" {
  description = "The resource group the network is in"
  value       = azurerm_resource_group.lab.name
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.lab.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.lab.address_space
}

output "subnets" {
  description = "Subnet names and their address ranges"
  value = {
    (azurerm_subnet.web.name) = azurerm_subnet.web.address_prefixes[0]
    (azurerm_subnet.app.name) = azurerm_subnet.app.address_prefixes[0]
  }
}

output "web_nsg_name" {
  description = "NSG attached to the web subnet"
  value       = azurerm_network_security_group.web.name
}
```

### Step 7: Check all four files are there

```powershell
dir
```

**Expected output** (dates and sizes will differ):

```
Mode    Name
----    ----
-a----  main.tf
-a----  outputs.tf
-a----  providers.tf
-a----  variables.tf
```

> If a file shows as `main.tf.txt`, Notepad has added `.txt`. Rename it with `Rename-Item main.tf.txt main.tf`.

### Step 8: Sign in to Azure

```powershell
az login
```

**What it does:** opens a browser window to sign in to Azure. If you are asked to choose a subscription, type its number and press **Enter**, or just press **Enter** to keep the default.

```powershell
az account show --output table
```

**What it does:** shows which subscription you are signed in to. Check that **State** says `Enabled`.

### Step 9: Tell Terraform which subscription to use

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

**What it does:** stores your subscription ID in a temporary setting that Terraform reads. It keeps the ID out of your code and out of GitHub. **This line prints nothing when it works.**

Check it worked:

```powershell
if ($env:ARM_SUBSCRIPTION_ID) { "Subscription ID is set" } else { "NOT set" }
```

**Expected output:**

```
Subscription ID is set
```

> This setting is lost when you close PowerShell. Run the `$env:ARM_SUBSCRIPTION_ID` line again every time you open a new PowerShell window.

### Step 10: Initialise Terraform

```powershell
terraform init
```

**What it does:** downloads the Azure provider (plugin) into a hidden `.terraform` folder and creates `.terraform.lock.hcl`. Every lab folder is a separate project, so each one needs its own `init`.

**Expected output** (the version number may be newer):

```
- Installing hashicorp/azurerm v4.81.0...
- Installed hashicorp/azurerm v4.81.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

### Step 11: Tidy and check the code

```powershell
terraform fmt
```

**What it does:** tidies the spacing in your files. It prints the names of any files it changed, or nothing if they were already tidy. Both are fine.

```powershell
terraform validate
```

**What it does:** checks the code for mistakes, without connecting to Azure.

**Expected output:**

```
Success! The configuration is valid.
```

### Step 12: Preview the changes

```powershell
terraform plan
```

**What it does:** connects to Azure and shows exactly what would be created, without creating anything.

**Expected output** (end of the plan):

```
Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + resource_group_name = "rg-tflab02-uks"
  + subnets             = {
      + snet-app = "10.10.2.0/24"
      + snet-web = "10.10.1.0/24"
    }
  + vnet_name           = "vnet-tflab02-uks"
  + web_nsg_name        = "nsg-web"
```

The plan lists resources alphabetically, not in the order they will be built.

### Step 13: Build it

```powershell
terraform apply
```

**What it does:** shows the plan again, then asks for confirmation. Type `yes` and press **Enter**.

The real build order only shows during the apply:

| Order | Resource | Why |
|---|---|---|
| 1 | Resource group | Everything else lives inside it |
| 2 | Virtual network and `nsg-web` (in parallel) | Both only need the resource group |
| 3 | `snet-web` and `snet-app` | Both need the virtual network |
| 4 | NSG association | Needs both `snet-web` and `nsg-web`, so it started as soon as those existed |

The subnet and association steps took around 40 seconds, as Azure processes changes to subnets in the same VNet one at a time.

**Expected output:**

```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

### Step 14: Check the network in Azure

List the subnets and their NSGs:

```powershell
az network vnet subnet list --resource-group rg-tflab02-uks --vnet-name vnet-tflab02-uks --query "[].{Name:name, Range:addressPrefix, NSG:networkSecurityGroup.id}" --output table
```

**What it does:** shows each subnet, its address range and the ID of any NSG attached.

**Expected output** (IDs shortened):

```
Name      Range         NSG
--------  ------------  -----------------------------------------------
snet-app  10.10.2.0/24
snet-web  10.10.1.0/24  /subscriptions/<subscription-id>/.../nsg-web
```

`snet-app` has no NSG yet. This is fixed in Test 1.

List all the rules on `nsg-web`, including the Azure defaults:

```powershell
az network nsg rule list --resource-group rg-tflab02-uks --nsg-name nsg-web --include-default --output table
```

**What it does:** shows your rules plus the default rules Azure adds to every NSG.

| Priority | Rule | Effect |
|---|---|---|
| 100 | Allow-HTTPS-Inbound | My rule |
| 65000 | AllowVnetInBound | Anything inside the VNet can reach anything else, on any port |
| 65001 | AllowAzureLoadBalancerInBound | Azure health probes |
| 65500 | DenyAllInBound | Everything else blocked, like the implicit deny at the end of an ACL |

The `AllowVnetInBound` default was the key finding. It meant `snet-app` was wide open to anything in the VNet.

---

## Tests carried out

### Test 1: Locking down the app tier

**Goal:** only allow the web tier to reach the app tier, on TCP 8080.

**1.** Open `main.tf`:

```powershell
notepad main.tf
```

**2.** Scroll to the **very bottom** of the file, add the following code, then save and close:

```hcl
# Network security group for the app tier: only the web tier can reach it
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
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

# Attach the NSG to the app subnet
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

| Priority | Rule | Effect |
|---|---|---|
| 100 | Allow-Web-To-App-8080 | Allows TCP 8080 from `10.10.1.0/24` (the web subnet) only |
| 4000 | Deny-VNet-Inbound | Blocks all other traffic from inside the VNet |

The deny rule at 4000 overrides the Azure default `AllowVnetInBound` at 65000, because lower priority numbers are processed first.

**3.** Preview the change:

```powershell
terraform plan
```

**Expected output:**

```
Plan: 2 to add, 0 to change, 0 to destroy.
```

The existing six resources were untouched. In the plan, the association already showed the real `subnet_id`, because the subnet existed, but the NSG ID was `(known after apply)`, so Terraform knew to create the NSG first.

**4.** Apply it:

```powershell
terraform apply
```

Type `yes` and press **Enter**.

**5.** Check both subnets now have an NSG:

```powershell
az network vnet subnet list --resource-group rg-tflab02-uks --vnet-name vnet-tflab02-uks --query "[].{Name:name, Range:addressPrefix, NSG:networkSecurityGroup.id}" --output table
```

**Expected output:** `snet-web` shows an ID ending in `nsg-web`, and `snet-app` shows an ID ending in `nsg-app`.

### Test 2: Security drift (RDP opened manually)

**Goal:** simulate someone opening RDP to the internet in a hurry and forgetting to close it, then see Terraform catch it.

> There are no VMs in this lab, so this rule does not expose anything. It is safe for testing.

**1.** Add the rule by hand in the Azure portal:

1. Go to [portal.azure.com](https://portal.azure.com) and sign in.
2. Search for **Resource groups** and open **rg-tflab02-uks**.
3. Click **nsg-web**.
4. In the left menu, click **Settings**, then **Inbound security rules**.
5. Click **+ Add** and fill in:
   - **Source:** `Any`
   - **Source port ranges:** `*`
   - **Destination:** `Any`
   - **Service:** `RDP` (this fills in port 3389)
   - **Action:** `Allow`
   - **Priority:** `110`
   - **Name:** `Allow-RDP-Manual`
6. Click **Add**. Azure shows a warning about exposing RDP; continue.

**2.** Back in PowerShell, check for drift:

```powershell
terraform plan
```

**Expected output** (shortened):

```
  ~ resource "azurerm_network_security_group" "web" {
      ~ security_rule = [
          - {
              - destination_port_range = "3389"
              - name                   = "Allow-RDP-Manual"
              - source_address_prefix  = "*"
            },
          ...
        ]
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Terraform found the manual rule and planned to remove it, because it is not in the code.

The plan also showed my HTTPS rule being removed and added back with identical values. This initially looked concerning, but it is because the rules are defined as one list inside the NSG resource, so Terraform rewrites the whole list when anything in it changes. Comparing the `-` and `+` blocks confirmed nothing was actually changing for that rule. The only real change was the RDP rule being removed.

**3.** Correct the drift:

```powershell
terraform apply
```

Type `yes` and press **Enter**.

**4.** Confirm the RDP rule has gone:

```powershell
az network nsg rule list --resource-group rg-tflab02-uks --nsg-name nsg-web --output table
```

**Expected output:** only `Allow-HTTPS-Inbound` is listed.

```
Name                 Priority    Access    Protocol    Direction    DestinationPortRanges
Allow-HTTPS-Inbound  100         Allow     Tcp         Inbound      443
```

The RDP rule was removed within two seconds. In a production setting, running `terraform plan` on a schedule would flag this kind of change automatically.

---

## Clean up

**Always destroy lab resources when you finish.**

```powershell
terraform destroy
```

**What it does:** removes everything this lab created. It shows what will be destroyed and asks for confirmation. Type `yes` and press **Enter**.

**Expected output:**

```
Destroy complete! Resources: 8 destroyed.
```

The destroy ran in reverse order: NSG associations first (a subnet or NSG cannot be deleted while linked), then the subnets and NSGs, then the VNet, and the resource group last.

Confirm it has gone:

```powershell
az group list --output table
```

**Expected output:** `rg-tflab02-uks` is **not** in the list.

---

## Command reference

| Command | What it does |
|---|---|
| `cd <folder>` | Moves into a folder |
| `mkdir <folder>` | Creates a folder |
| `Copy-Item <source> <destination>` | Copies a file |
| `notepad <file>` | Opens or creates a file in Notepad |
| `dir` | Lists the files in the current folder |
| `az login` | Signs in to Azure |
| `az account show --output table` | Shows the active subscription |
| `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` | Tells Terraform which subscription to use |
| `terraform init` | Downloads the provider for this lab folder |
| `terraform fmt` | Tidies code layout |
| `terraform validate` | Checks the code for errors |
| `terraform plan` | Previews changes |
| `terraform apply` | Builds or updates the infrastructure |
| `terraform destroy` | Removes everything, in reverse dependency order |
| `az network vnet subnet list ...` | Lists subnets with their ranges and attached NSGs |
| `az network nsg rule list ... --include-default` | Lists custom and Azure default NSG rules |
| `az group list --output table` | Lists all resource groups |

## Troubleshooting (issues I hit)

| Problem | Cause | Fix |
|---|---|---|
| `The term 'resource_group_name' is not recognized` in PowerShell | I pasted a line of Terraform code into PowerShell by mistake | Terraform code goes in `.tf` files, not the terminal. No harm done |
| Terraform could not authenticate after signing in to Azure again | The `ARM_SUBSCRIPTION_ID` setting is lost when the session changes | Run `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` again |
| Signing in with `az login` added my Microsoft account to Windows | Newer Azure CLI versions use the Windows sign-in broker by default | Run `az config set core.enable_broker_on_windows=false`, then `az login` again for a browser-only sign-in |
| A file shows as `main.tf.txt` | Notepad added `.txt` to the name | `Rename-Item main.tf.txt main.tf` |

## What I learned

- Terraform works out build and destroy order from the references between resources. I never had to specify it.
- Azure NSGs behave much like ACLs: rules are processed by priority, and there is an implicit deny at the end. The big difference is `AllowVnetInBound`, which allows all traffic inside the VNet by default. Proper segmentation needs an explicit deny rule to override it.
- A plan that looks alarming is not always dangerous. Reading the `-` and `+` blocks carefully showed the HTTPS rule was not really changing.
- Drift detection is a practical security control. A risky manual change, like RDP open to the internet, is caught and reverted by the next plan and apply.
- Using a map for tags and references between resources keeps the code short and means values only need changing in one place.