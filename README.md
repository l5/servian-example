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
* I worked with a "main" branch + feature branches as well as PRs; this seemed reasonable for me working alone on the project and still achieving a level of traceability that allows judging my work style. In a larger setting I might work with an additional DEV branch and releases or a ready-to-go fully featured concept.
* Settings pass through docker. That's not ideal, as credentials are stored in clear text in the docker state file. Ideally, the solution would use a managed identity to get the credentials from a key vault.
* I wanted to use application container service and tried hard, but:
  * scalability was in practice much more limited than advertised on the web
  * container configuration is not well documented, especially via terraform
  * it seemed like via terraform it is possible to work on web apps, but not on container web apps.
  * I did not find out how to pass a command to the container
  Therefore... looking at AKS, now.



## Requirement Checklist

- [x] Works in empty cloud subscription: Yes; creates a resource group.
- [] Use release package; do not compile
- [] Not connected to a particular cloud account
[] Regular commits; git workflow
[] Documentation: Pre-requisites
[] Documentation: High-Level Architecture
[] Documentation: Process instructions for provisioning
[] Able to start from a cloned git repo
[] Pre-requisites clearly documented
[] Contained within a github repo
[] Deploys via automated process
[] Deploys infrastructure using code
[] Code is clear
[] Code contains comments
[] Coding is consistent
[] Security: Network segmentation?
[] Security: Secret storage
[] Security: Platform security features
[] Simplicity: No superfluous dependencies
[] Simplicity: Not over engineered
[] Resiliency: Auto scaling
[] Resiliency: Highly available frontend
[] Resiliency: Highly available database
