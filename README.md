# servian-example

## Prerequisites

* terraform 1.1.7 (see https://www.terraform.io/downloads)
* latest `ac cli` version (see https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
* valid sku size configured (az postgres flexible-server list-skus --location eastus)

* Tested in WSL2 / Ubuntu-20.04
* Subscription and its id in Azure.


## Run via (linux) command line

1. Clone repositoy
1. cd into cloned repository
1. Set env variables:
   ```
   export TF_VAR_subscription_id="<azure subscription id>"
   export TF_VAR_db_user="<admin user name for db>"
   export TF_VAR_db_password="<admin password for db>"
   ```
1. `terraform init`
1. `terraform plan`; check for any issues
1. `terraform apply`



## Explanations, limits, issues, assumptions

* The task states we should start from an empty account. I chose to start from an existing subscription instead of creating a new one via terraform, as in Azure usually there would be one default subscription already upon creation of an account.
