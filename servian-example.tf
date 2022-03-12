# This terraform file creates the database infrastructure.

#
# Used elements:
#  * Azure Postgresql Flexible Server: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
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
  name                   = "servian-psqlflexibleserver-dc2022" # needs to be unique across azure
  resource_group_name    = azurerm_resource_group.servian.name
  location               = azurerm_resource_group.servian.location
  version                = "11" # This is an untested version for the app, but Azure only offers the supported version "10" in a non-high-availability scenario
  administrator_login    = var.db_user
  administrator_password = var.db_password

  # ToDo: Include high availability
  storage_mb = 32768 # this is the minimum value and should be enough for a demo app

  sku_name   = "B_Standard_B1ms" # Check tf documentation for format; using smallest possible here as it is a demo
  # ToDo: Update to high availability capable size
}
