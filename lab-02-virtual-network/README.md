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

Below I have written up every step I took, the commands I ran and what I saw, so anyone can follow the same process.

## Architecture

```
Resource group: rg-tflab02-uks
└── Virtual network: vnet-tflab02-uks (10.10.0.0/16)
    ├── snet-web (10.10.1.0/24)  ── nsg-web: allow HTTPS (443) from the internet
    └── snet-app (10.10.2.0/24)  ── nsg-app: allow TCP 8080 from snet-web only, deny all other VNet traffic
```

---

## Following along?

If you want to repeat this lab yourself, a few pointers:

- I ran every command in **Windows PowerShell** (Start, type `PowerShell`, select **Windows PowerShell**).
- Each command is in its own box. Run **one line at a time**, pressing **Enter** after each, and let it finish before running the next.
- Anything in `<angle brackets>` needs replacing with your own value, **brackets included**. For example, `<your-folder-path>` becomes `C:\terraform-labs`.
- Boxes marked **What I saw** show my output, so you can compare. They are not commands to run.
- Code in `hcl` boxes is Terraform code. It goes **inside the `.tf` files**, not into PowerShell.
- When Terraform asks `Enter a value:`, type the full word `yes` and press **Enter**. Anything else cancels.

You will need the tools listed in the [main README prerequisites](../README.md#prerequisites). If you are new to Terraform, [Lab 01](../lab-01-resource-group) covers the basic workflow used here.

---

## Files in this lab

| File | Purpose |
|---|---|
| `providers.tf` | Azure provider and version constraints |
| `variables.tf` | Region, resource group name, address ranges and a shared map of tags |
| `main.tf` | The network, subnets, NSGs and associations |
| `outputs.tf` | A summary of the network after it is built |
| `.terraform.lock.hcl` | Created automatically by `terraform init`. Records the exact provider version used |

## What was new compared with Lab 01

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

## How I built it

### Step 1: Created the lab folder

I opened Windows PowerShell and moved into my labs folder:

```powershell
cd C:\terraform-labs
```

> If your labs folder is somewhere else, use `cd <your-folder-path>`.

I then created a folder for this lab:

```powershell
mkdir lab-02-virtual-network
```

And moved into it, so the prompt ended in `\lab-02-virtual-network>`:

```powershell
cd lab-02-virtual-network
```

### Step 2: Reused the provider file from Lab 01

Every lab uses the same provider settings, so rather than write the file again I copied it across:

```powershell
Copy-Item ..\lab-01-resource-group\providers.tf .
```

`..` means "the folder above this one", and the final `.` means "into this folder". I checked it had copied:

```powershell
Get-Content providers.tf
```

**What I saw:**

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

> If you skipped Lab 01, create this file yourself: run `notepad providers.tf`, click **Yes** to create it, paste in the code above, then save and close.

### Step 3: Wrote the variables file

I created `variables.tf`:

```powershell
notepad variables.tf
```

Notepad asked whether to create the file, so I clicked **Yes**, pasted in the following, saved and closed it:

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
    owner       = "iM-MQ"
  }
}
```

> Following along? Change `owner = "iM-MQ"` to your own name or username.

For the IP plan I used a `/16` for the VNet and carved it into `/24` subnets, the same approach I would take when subnetting on-premises.

### Step 4: Wrote the main configuration

I created `main.tf`:

```powershell
notepad main.tf
```

I clicked **Yes**, pasted in the following, saved and closed it:

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

I started with the web tier only. The app tier NSG (`nsg-app`) was added later in [Test 1](#test-1-locking-down-the-app-tier), which is why the finished `main.tf` in this repo is longer.

### Step 5: Wrote the outputs file

I created `outputs.tf` so Terraform would print a summary of the network after building it:

```powershell
notepad outputs.tf
```

I clicked **Yes**, pasted in the following, saved and closed it:

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

### Step 6: Checked all four files were there

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

### Step 7: Signed in to Azure

```powershell
az login
```

This opened a browser to sign in. I only have one subscription, so when asked to choose I pressed **Enter** to keep the default. I then confirmed the subscription was active:

```powershell
az account show --output table
```

**State** showed `Enabled`.

### Step 8: Told Terraform which subscription to use

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
```

This stores the subscription ID in a temporary setting that Terraform reads, which keeps it out of the code and out of GitHub. It prints nothing when it works, so I checked it:

```powershell
if ($env:ARM_SUBSCRIPTION_ID) { "Subscription ID is set" } else { "NOT set" }
```

**What I saw:**

```
Subscription ID is set
```

> This setting is lost when PowerShell is closed, so the `$env:ARM_SUBSCRIPTION_ID` line needs running again in every new window.

### Step 9: Initialised Terraform

```powershell
terraform init
```

Each lab folder is a separate Terraform project, so it needs its own `init`. This downloaded the Azure provider and created the `.terraform.lock.hcl` file.

**What I saw:**

```
- Installing hashicorp/azurerm v4.81.0...
- Installed hashicorp/azurerm v4.81.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

It installed v4.81.0, the latest release allowed by the `~> 4.0` constraint.

### Step 10: Tidied and checked the code

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

### Step 11: Previewed the changes

```powershell
terraform plan
```

**What I saw** (end of the plan):

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

One thing I noticed: the plan lists resources alphabetically, not in the order they will be built.

### Step 12: Built the network

```powershell
terraform apply
```

Terraform showed the plan again and asked for confirmation, so I typed `yes` and pressed **Enter**.

Watching the output, I could see the real build order:

| Order | Resource | Why |
|---|---|---|
| 1 | Resource group | Everything else lives inside it |
| 2 | Virtual network and `nsg-web` (in parallel) | Both only need the resource group |
| 3 | `snet-web` and `snet-app` | Both need the virtual network |
| 4 | NSG association | Needs both `snet-web` and `nsg-web`, so it started as soon as those existed |

The subnet and association steps took around 40 seconds, as Azure processes changes to subnets in the same VNet one at a time.

**What I saw:**

```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

### Step 13: Checked the network in Azure

I listed the subnets and any NSGs attached to them:

```powershell
az network vnet subnet list --resource-group rg-tflab02-uks --vnet-name vnet-tflab02-uks --query "[].{Name:name, Range:addressPrefix, NSG:networkSecurityGroup.id}" --output table
```

**What I saw** (IDs shortened):

```
Name      Range         NSG
--------  ------------  -----------------------------------------------
snet-app  10.10.2.0/24
snet-web  10.10.1.0/24  /subscriptions/<subscription-id>/.../nsg-web
```

`nsg-web` was attached to `snet-web`, and `snet-app` had no NSG.

I then listed every rule on `nsg-web`, including the defaults Azure adds to every NSG:

```powershell
az network nsg rule list --resource-group rg-tflab02-uks --nsg-name nsg-web --include-default --output table
```

| Priority | Rule | Effect |
|---|---|---|
| 100 | Allow-HTTPS-Inbound | My rule |
| 65000 | AllowVnetInBound | Anything inside the VNet can reach anything else, on any port |
| 65001 | AllowAzureLoadBalancerInBound | Azure health probes |
| 65500 | DenyAllInBound | Everything else blocked, like the implicit deny at the end of an ACL |

`AllowVnetInBound` was the key finding. It meant `snet-app` was wide open to anything in the VNet, which led to Test 1.

---

## Tests I carried out

### Test 1: Locking down the app tier

**Goal:** only allow the web tier to reach the app tier, on TCP 8080.

I opened `main.tf` again:

```powershell
notepad main.tf
```

I added the following to the **very bottom** of the file, then saved and closed it:

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

I previewed the change:

```powershell
terraform plan
```

**What I saw:**

```
Plan: 2 to add, 0 to change, 0 to destroy.
```

The existing six resources were untouched. In the plan, the association already showed the real `subnet_id`, because the subnet existed, but the NSG ID was `(known after apply)`, so Terraform knew to create the NSG first.

I applied it, typing `yes` when asked:

```powershell
terraform apply
```

Then I checked both subnets had an NSG:

```powershell
az network vnet subnet list --resource-group rg-tflab02-uks --vnet-name vnet-tflab02-uks --query "[].{Name:name, Range:addressPrefix, NSG:networkSecurityGroup.id}" --output table
```

**What I saw:** `snet-web` showed an ID ending in `nsg-web`, and `snet-app` showed an ID ending in `nsg-app`.

### Test 2: Security drift (RDP opened manually)

**Goal:** simulate someone opening RDP to the internet in a hurry and forgetting to close it, then see whether Terraform catches it.

> There were no VMs in this lab, so the rule did not expose anything.

I added the rule by hand in the Azure portal:

1. Went to [portal.azure.com](https://portal.azure.com) and signed in.
2. Searched for **Resource groups** and opened **rg-tflab02-uks**.
3. Clicked **nsg-web**.
4. In the left menu, clicked **Settings**, then **Inbound security rules**.
5. Clicked **+ Add** and filled in:
   - **Source:** `Any`
   - **Source port ranges:** `*`
   - **Destination:** `Any`
   - **Service:** `RDP` (this fills in port 3389)
   - **Action:** `Allow`
   - **Priority:** `110`
   - **Name:** `Allow-RDP-Manual`
6. Clicked **Add**. Azure warned about exposing RDP, and I continued.

Back in PowerShell, I checked for drift:

```powershell
terraform plan
```

**What I saw** (shortened):

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

I applied the plan, typing `yes` when asked:

```powershell
terraform apply
```

Then I confirmed the RDP rule had gone:

```powershell
az network nsg rule list --resource-group rg-tflab02-uks --nsg-name nsg-web --output table
```

**What I saw:**

```
Name                 Priority    Access    Protocol    Direction    DestinationPortRanges
Allow-HTTPS-Inbound  100         Allow     Tcp         Inbound      443
```

The RDP rule was removed within two seconds. In a production setting, running `terraform plan` on a schedule would flag this kind of change automatically.

---

## Clean up

Once I had finished testing, I destroyed everything, typing `yes` when asked:

```powershell
terraform destroy
```

**What I saw:**

```
Destroy complete! Resources: 8 destroyed.
```

The destroy ran in reverse order: NSG associations first (a subnet or NSG cannot be deleted while linked), then the subnets and NSGs, then the VNet, and the resource group last.

I confirmed the resource group had gone:

```powershell
az group list --output table
```

`rg-tflab02-uks` was no longer listed.

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

## Issues I hit and how I fixed them

| Problem | Cause | Fix |
|---|---|---|
| `The term 'resource_group_name' is not recognized` in PowerShell | I pasted a line of Terraform code into PowerShell by mistake | Terraform code goes in `.tf` files, not the terminal. No harm done |
| Terraform could not authenticate after I signed in to Azure again | The `ARM_SUBSCRIPTION_ID` setting is lost when the session changes | Ran `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` again |
| Signing in with `az login` added my Microsoft account to Windows | Newer Azure CLI versions use the Windows sign-in broker by default | Ran `az config set core.enable_broker_on_windows=false`, then `az login` again for a browser-only sign-in |

## What I learned

- Terraform works out build and destroy order from the references between resources. I never had to specify it.
- Azure NSGs behave much like ACLs: rules are processed by priority, and there is an implicit deny at the end. The big difference is `AllowVnetInBound`, which allows all traffic inside the VNet by default. Proper segmentation needs an explicit deny rule to override it.
- A plan that looks alarming is not always dangerous. Reading the `-` and `+` blocks carefully showed the HTTPS rule was not really changing.
- Drift detection is a practical security control. A risky manual change, like RDP open to the internet, is caught and reverted by the next plan and apply.
- Using a map for tags and references between resources keeps the code short and means values only need changing in one place.