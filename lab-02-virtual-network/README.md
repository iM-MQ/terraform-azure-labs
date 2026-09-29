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

## Files

| File | Purpose |
|---|---|
| `providers.tf` | Azure provider and version constraints (copied from Lab 01) |
| `variables.tf` | Region, resource group name, address ranges and a shared map of tags |
| `main.tf` | The network, subnets, NSGs and associations |
| `outputs.tf` | A summary of the network after it is built |
| `.terraform.lock.hcl` | Records the exact provider version used |

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

### 1. Set up the lab

```powershell
cd C:\terraform-labs
mkdir lab-02-virtual-network
cd lab-02-virtual-network
Copy-Item ..\lab-01-resource-group\providers.tf .
```

I reused `providers.tf` from Lab 01, as every lab needs the same provider settings.

### 2. Sign in and initialise

```powershell
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv
terraform init
terraform fmt
terraform validate
```

Each lab folder is a separate Terraform project, so it needs its own `init`. This installed `azurerm` v4.81.0, the latest release allowed by the `~> 4.0` constraint.

### 3. Plan

```powershell
terraform plan
```

```
Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + subnets = {
      + snet-app = "10.10.2.0/24"
      + snet-web = "10.10.1.0/24"
    }
```

One thing I noticed: the plan lists resources alphabetically, not in the order they will be built.

### 4. Apply and watch the build order

```powershell
terraform apply
```

The real order only showed during the apply:

| Order | Resource | Why |
|---|---|---|
| 1 | Resource group | Everything else lives inside it |
| 2 | Virtual network and `nsg-web` (in parallel) | Both only need the resource group |
| 3 | `snet-web` and `snet-app` | Both need the virtual network |
| 4 | NSG association | Needs both `snet-web` and `nsg-web`, so it started as soon as those existed |

The subnet and association steps took around 40 seconds, as Azure processes changes to subnets in the same VNet one at a time.

```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

### 5. Verify in Azure

```powershell
az network vnet subnet list --resource-group rg-tflab02-uks --vnet-name vnet-tflab02-uks --query "[].{Name:name, Range:addressPrefix, NSG:networkSecurityGroup.id}" --output table
az network nsg rule list --resource-group rg-tflab02-uks --nsg-name nsg-web --include-default --output table
```

The first command confirmed `nsg-web` was attached to `snet-web` and that `snet-app` had no NSG. The second showed my HTTPS rule at priority 100 alongside the Azure default rules:

| Priority | Rule | Effect |
|---|---|---|
| 100 | Allow-HTTPS-Inbound | My rule |
| 65000 | AllowVnetInBound | Anything inside the VNet can reach anything else, on any port |
| 65001 | AllowAzureLoadBalancerInBound | Azure health probes |
| 65500 | DenyAllInBound | Everything else blocked, like the implicit deny at the end of an ACL |

The `AllowVnetInBound` default was the key finding. It meant `snet-app` was wide open to anything in the VNet, which led to Test 1.

---

## Tests carried out

### Test 1: Locking down the app tier

I added `nsg-app` with two rules and attached it to `snet-app`:

| Priority | Rule | Effect |
|---|---|---|
| 100 | Allow-Web-To-App-8080 | Allows TCP 8080 from `10.10.1.0/24` (the web subnet) only |
| 4000 | Deny-VNet-Inbound | Blocks all other traffic from inside the VNet |

The deny rule at 4000 overrides the Azure default `AllowVnetInBound` at 65000, because lower priority numbers are processed first.

```
Plan: 2 to add, 0 to change, 0 to destroy.
```

The existing six resources were untouched. In the plan, the association already showed the real `subnet_id`, because the subnet existed, but the NSG ID was `(known after apply)`, so Terraform knew to create the NSG first.

### Test 2: Security drift (RDP opened manually)

To simulate someone opening RDP in a hurry and forgetting to close it, I added a rule directly in the portal on `nsg-web`: allow TCP 3389 from any source, priority 110, named `Allow-RDP-Manual`.

`terraform plan` picked it up straight away:

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

The plan also showed my HTTPS rule being removed and added back with identical values. This initially looked concerning, but it is because the rules are defined as one list inside the NSG resource, so Terraform rewrites the whole list when anything in it changes. Comparing the `-` and `+` blocks confirmed nothing was actually changing for that rule. The only real change was the RDP rule being removed.

After applying, the RDP rule was gone within two seconds:

```powershell
az network nsg rule list --resource-group rg-tflab02-uks --nsg-name nsg-web --output table
```

```
Name                 Priority    Access    Protocol    Direction    DestinationPortRanges
Allow-HTTPS-Inbound  100         Allow     Tcp         Inbound      443
```

In a production setting, running `terraform plan` on a schedule would flag this kind of change automatically.

### Clean up

```powershell
terraform destroy
```

```
Destroy complete! Resources: 8 destroyed.
```

The destroy ran in reverse order: NSG associations first (a subnet or NSG cannot be deleted while linked), then the subnets and NSGs, then the VNet, and the resource group last.

---

## Command reference

| Command | What it does |
|---|---|
| `Copy-Item ..\lab-01-resource-group\providers.tf .` | Reuses the provider settings from Lab 01 |
| `terraform init` | Downloads the provider for this lab folder |
| `terraform plan` | Previews changes |
| `terraform apply` | Builds or updates the infrastructure |
| `terraform destroy` | Removes everything, in reverse dependency order |
| `az network vnet subnet list ...` | Lists subnets with their ranges and attached NSGs |
| `az network nsg rule list ... --include-default` | Lists custom and Azure default NSG rules |

## Troubleshooting (issues I hit)

| Problem | Cause | Fix |
|---|---|---|
| `The term 'resource_group_name' is not recognized` in PowerShell | I pasted a line of Terraform code into PowerShell by mistake | Terraform code goes in `.tf` files, not the terminal. No harm done |
| Terraform could not authenticate after signing in to Azure again | The `ARM_SUBSCRIPTION_ID` environment variable is lost when the session changes | Re-run `$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv` |
| Signing in with `az login` added my Microsoft account to Windows | Newer Azure CLI versions use the Windows sign-in broker by default | `az config set core.enable_broker_on_windows=false`, then `az login` again for a browser-only sign-in |

## What I learned

- Terraform works out build and destroy order from the references between resources. I never had to specify it.
- Azure NSGs behave much like ACLs: rules are processed by priority, and there is an implicit deny at the end. The big difference is `AllowVnetInBound`, which allows all traffic inside the VNet by default. Proper segmentation needs an explicit deny rule to override it.
- A plan that looks alarming is not always dangerous. Reading the `-` and `+` blocks carefully showed the HTTPS rule was not really changing.
- Drift detection is a practical security control. A risky manual change, like RDP open to the internet, is caught and reverted by the next plan and apply.
- Using a map for tags and references between resources keeps the code short and means values only need changing in one place.