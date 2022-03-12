# This terraform file creates the database infrastructure.

#
# Used elements:
#  * Azure Postgresql Flexible Server: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
#  * Azure App Service: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service
#


# We use variables here so we don't need to have the credentials in the repo
variable "db_user" {
    type = string
    description = "The username for the postgresql db"
}
variable "db_password" {
    type = string
    description = "The password for the postgresql db"
}
variable "subscription_id" {
    type = string
    description = "The id of the azure subscription the app should be installed in"
}

# ToDo: Document setting env vars etc.

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

resource "azurerm_postgresql_flexible_server" "servian" {
  # ToDo: VNET enforcement, as ssl is not possible
  name                   = "servian-psqlflexibleserver-dc2022" # needs to be unique across azure
  resource_group_name    = azurerm_resource_group.servian.name
  location               = azurerm_resource_group.servian.location
  version                = "11" # This is an untested version for the app, but Azure only offers the supported version "10" in a non-high-availability scenario
  administrator_login    = var.db_user
  administrator_password = var.db_password
  zone = 3 # If this is not static, the resource will be re-created each time tf apply is invoked

  # ToDo: Include high availability
  storage_mb = 32768 # this is the minimum value and should be enough for a demo app

  sku_name   = "B_Standard_B1ms" # Check tf documentation for format; using smallest possible here as it is a demo
  # ToDo: Update to high availability capable size
}

/* It seems like SSL is not enabled in the golang app / psql connection. We could either enable it in the code and 
   create a new docker image, or we disable it on the server. The latter solution is not appropriate for production 
   installations for security versions, but as the task explicitly states that re-building the app should not be 
   necessary, we switch the SSL/TLS requirement off on the db server. */
resource "azurerm_postgresql_flexible_server_configuration" "ssl_off" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.servian.id
  value     = "off"
}


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
  name                = "servian-dc-202203-appservice"
  location            = azurerm_resource_group.servian.location
  resource_group_name = azurerm_resource_group.servian.name
  app_service_plan_id = azurerm_app_service_plan.servian.id
  

  site_config {
      linux_fx_version  = "DOCKER|servian/techchallengeapp:latest" #define the images to usecfor you application
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
    VTT_LISTENPORT = 80
  }
  https_only = true
  #app_settings = {
  #  "DOCKER_REGISTRY_SERVER_URL"      = "https://mcr.microsoft.com",
  #  "DOCKER_REGISTRY_SERVER_USERNAME" = "",
  #  "DOCKER_REGISTRY_SERVER_PASSWORD" = "",
  #}
}
