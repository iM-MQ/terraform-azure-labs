# Terraform Azure Labs

Hands-on labs learning **Terraform** by building real **Azure** infrastructure as code, using the `azurerm` provider. Each lab builds on the previous one and is deployed, tested and destroyed in my own Azure subscription.

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
