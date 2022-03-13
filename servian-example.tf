# This terraform file creates the database infrastructure.

#
# Used elements:
#  * Azure Postgresql Flexible Server: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
#  * Azure App Service: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service
#


# We use variables here so we don't need to have the credentials in the repo
# The first three variables are mandatory to be set via environment variables before
# running the tf script (see documentation)
variable "db_user" {
    type = string
    description = "The username for the postgresql db"
}
variable "db_password" {
    type = string
    description = "The password for the postgresql db"
    sensitive   = true
}
variable "subscription_id" {
    type = string
    description = "The id of the azure subscription the app should be installed in"
}

/* For the next few variables there should be no need to change them; except if someone else happened to 
 * choose the same globally unique names */
variable "database_server_name" {
    type = string
    description = "Globally unique (across azure) hostname for the postgresql flex server"
    default = "servian-psqlflexibleserver-dc2022"
}
variable "app_dns_name" {
    type = string
    description = "Globally unique (across azure) hostname for the web app"
    default = "servian-dc-202203-appservice"
}
variable "dns_zone_name" {
    type = string
    description = "Globally unique (across azure) name for the dns zone"
    default = "servian-dc-202203-appservice"
}

terraform {
    required_providers {
        azurerm = {
            /* it is recommended to be pinned according to https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/3.0-overview,
                as the upgrade to 3.0 seems to be coming up soon - with breaking changes. */
            version = "=2.99.0"
        }  
    }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id # should be explicit, as otherwise the infrastructure might land in the wrong one.
}

resource "azurerm_resource_group" "servian" {
  name     = "servian-example"
  location = "East US" # location does not really matter; East US is cheap and good enough for demos. Would use a location nearby for real-life purposes.
}

/**********************************
 *********** Database *************
 **********************************/

/* We use a flex server, as these can be configured with high-availability features */
resource "azurerm_postgresql_flexible_server" "servian" {
  name                   = var.database_server_name # needs to be unique across azure
  resource_group_name    = azurerm_resource_group.servian.name
  location               = azurerm_resource_group.servian.location
  version                = "11" # This is an untested version for the app, but Azure only offers the supported version "10" in a non-high-availability scenario
  administrator_login    = var.db_user
  administrator_password = var.db_password
  zone                   = 3 # If this is not static, the resource will be re-created each time tf apply is invoked
  delegated_subnet_id    = azurerm_subnet.serviansubnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.servian.id
  depends_on = [azurerm_private_dns_zone_virtual_network_link.servian]

  storage_mb = 32768 # this is the minimum value and should be enough for a demo app

  /* B_Standard_B1ms is the smallest possibility without high availability; GP_Standard_D2ds_v4 for high availability */
  sku_name   = "GP_Standard_D2ds_v4" # Check tf documentation for format

  high_availability {
    mode = "ZoneRedundant"
  }
}

/* It seems like SSL is not enabled in the golang app / psql connection. We could either enable it in the code and 
 * create a new docker image, or we disable it on the server. The latter solution is not appropriate for production 
 * installations for security versions, but as the task explicitly states that re-building the app should not be 
 * necessary, we switch the SSL/TLS requirement off on the db server. */
resource "azurerm_postgresql_flexible_server_configuration" "ssl_off" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.servian.id
  value     = "off"
}

/**********************************
 *********** Web app **************
 **********************************/
resource "azurerm_app_service_plan" "servian" {
  name                = "servian-appserviceplan"
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name
  kind = "Linux"
  sku {
    tier = "Standard"
    size = "S1" # "Standard" seems to be the lowest one supporting autoscaling
  }
    reserved = true # Mandatory for Linux plans
}

resource "azurerm_app_service" "example" {
  name                = var.app_dns_name
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name
  app_service_plan_id = azurerm_app_service_plan.servian.id
  depends_on = [azurerm_container_group.servian-seeding]

  site_config {
      linux_fx_version  = "DOCKER|servian/techchallengeapp:latest"
      always_on        = "true"
      app_command_line = "serve"
  }

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    VTT_DBUSER = var.db_user
    VTT_DBPASSWORD = var.db_password
    VTT_DBNAME = "postgres"
    VTT_DBPORT = 5432
    VTT_DBHOST = azurerm_postgresql_flexible_server.servian.fqdn
    VTT_LISTENHOST = "0.0.0.0"
    VTT_LISTENPORT = 80 # default for Azure web apps
  }
  https_only = true # it is more secure to switch http off
}

resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_app_service.example.id
  subnet_id      = azurerm_subnet.serviansubnetapp.id
}

/**********************************
 *********** Seeding Container ****
 **********************************/
resource "azurerm_container_group" "servian-seeding" {
  name                = "servian-seeding"
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name
  ip_address_type     = "private"
  os_type             = "Linux"
  depends_on = [azurerm_postgresql_flexible_server_configuration.ssl_off]
  network_profile_id = azurerm_network_profile.servian-vnet.id
  restart_policy      = "OnFailure"
  tags                = {}
  lifecycle {
    ignore_changes = [tags]
  }
  container {
    name   = "servian-seed"
    image  = "servian/techchallengeapp:latest"
    cpu    = "0.5"
    memory = "1.5"
    environment_variables = { # ToDo: Set to secure
        WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
        VTT_DBUSER = var.db_user
        VTT_DBNAME = "postgres"
        VTT_DBPORT = 5432
        VTT_DBHOST = azurerm_postgresql_flexible_server.servian.fqdn
        VTT_LISTENHOST = "0.0.0.0"
        VTT_LISTENPORT = 80
    }
    secure_environment_variables = {
      VTT_DBPASSWORD = var.db_password
    }
    commands = ["/TechChallengeApp/TechChallengeApp", "updatedb", "-s"]
  
    ports {
      port = 4141 # this is not necessary and could possibly be removed
      protocol = "TCP"
    }
  }
}

/**********************************
 *********** VNet **************
 **********************************/
resource "azurerm_virtual_network" "servianet" {
  name                = "servian-vn"
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "serviansubnet" {
  name                 = "servian-sn"
  resource_group_name  = azurerm_resource_group.servian.name
  virtual_network_name = azurerm_virtual_network.servianet.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
resource "azurerm_subnet" "serviansubnetapp" {
  name                 = "servian-snapp"
  resource_group_name  = azurerm_resource_group.servian.name
  virtual_network_name = azurerm_virtual_network.servianet.name
  address_prefixes     = ["10.0.3.0/24"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}
resource "azurerm_subnet" "serviansubnetseed" {
  name                 = "servian-snseed"
  resource_group_name  = azurerm_resource_group.servian.name
  virtual_network_name = azurerm_virtual_network.servianet.name
  address_prefixes     = ["10.0.5.0/24"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}
resource "azurerm_private_dns_zone" "servian" {
  name                = "{var.dns_zone_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.servian.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "servian" {
  name                  = "exampleVnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.servian.name
  virtual_network_id    = azurerm_virtual_network.servianet.id
  resource_group_name   = azurerm_resource_group.servian.name
}

resource "azurerm_network_profile" "servian-vnet" {
  name                = "serviannetprofile"
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name

  container_network_interface {
    name = "serviancnic"

    ip_configuration {
      name      = "servianipconfig"
      subnet_id = azurerm_subnet.serviansubnetseed.id
    }
  }
}


/**********************************
 *********** Autoscaling for app **
 **********************************/
resource "azurerm_monitor_autoscale_setting" "servian" {
  name                = "servianAutoscaleSetting"
  resource_group_name = azurerm_resource_group.servian.name
  location            = azurerm_resource_group.servian.location
  target_resource_id  = azurerm_app_service_plan.servian.id
  profile {
    name = "default"
    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.servian.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.servian.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }  
}

/**********************************
 *********** CDN **************
 **********************************/
resource "azurerm_cdn_profile" "servian" {
  name                = "servian-dc2022-cdn"
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "servian" {
  name                = "awesome-servian-example-app"
  profile_name        = azurerm_cdn_profile.servian.name
  location            = "global"
  resource_group_name = azurerm_resource_group.servian.name
  is_http_allowed     = true
  origin_host_header  = "{var.app_dns_name}.azurewebsites.net"
  lifecycle {
    ignore_changes = [tags]
  }
  origin {
    name      = "servian-webapp-origin"
    host_name = "{var.app_dns_name}.azurewebsites.net"
  }
}

