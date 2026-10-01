# Log Analytics workspace: collects the container's logs
resource "azurerm_log_analytics_workspace" "app" {
  name                = "log-assetreg-${random_string.suffix.result}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Container Apps environment: the shared space the app runs in
resource "azurerm_container_app_environment" "app" {
  name                       = "cae-assetreg"
  location                   = azurerm_resource_group.app.location
  resource_group_name        = azurerm_resource_group.app.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app.id
  tags                       = var.tags

  # Azure's default pay-per-use profile, declared so the code matches reality
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}



# The Asset Register itself, running your image
resource "azurerm_container_app" "web" {
  name                         = "ca-assetreg"
  container_app_environment_id = azurerm_container_app_environment.app.id
  resource_group_name          = azurerm_resource_group.app.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  # The database password, stored as a secret rather than plain text
  secret {
    name  = "db-password"
    value = random_password.db.result
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "web"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.db.fqdn
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_admin_username
      }

      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 5000
        path      = "/health"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 5000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # Don't start the app until its database and firewall rule exist
  depends_on = [
    azurerm_postgresql_flexible_server_database.assets,
    azurerm_postgresql_flexible_server_firewall_rule.azure_services,
  ]
}