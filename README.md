# DP Terraform Environments

## Terraform Structure

The prototype is divided into separate files corresponding to one part of the infrastructure.
All of these files are run at once when terraform runs. 

`common.tf` Common modules like VPCs, shared security groups and system wide secrets


## Deployment

To start a deployment, run the [DP Terraform Environments Deploy job in GitHub actions][github-actions-job] by clicking 'Run Workflow' and selecting the environment you want to deploy to. All changes must be deployed first to integration, then staging, then production.

The deployment will pause when Terraform has determined which changes need to be applied. Review the Terraform plan output by clicking the link provided in the Slack notification. This will be a link to Cloudwatch in the management account so you will need to be logged in to the management AWS account to use this.

Check whether the changes look correct, then open the actions approval page and accept or reject them. To find the actions approval page, follow the link from the Slack notification:

![Terraform deployment link in Slack](docs/images/slack-deployment-link.png)

Deployments can be approved by anyone in the `digital-records-repository` GitHub team.

[github-actions-job]: https://github.com/nationalarchives/dp-terraform-environments/actions/workflows/apply.yml

## Local development

### Install Terraform locally

See: https://learn.hashicorp.com/terraform/getting-started/install.html

### Install AWS CLI Locally

See: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

### Install Terraform Plugins on Intellij

HCL Language Support: https://plugins.jetbrains.com/plugin/7808-hashicorp-terraform--hcl-language-support

## Running Terraform Project Locally

**NOTE: Running Terraform locally should only be used to check the Terraform plan. Updating the DP environments should only ever be done through GitHub actions**

1. Clone DP Environments project to local machine: https://github.com/nationalarchives/dp-terraform-environments and navigate to the directory

2. Switch to the Terraform workspace corresponding to the DP environment to be worked on:

   ```
   [location of project] $ terraform workspace select intg
   ```

3. Set the following Terraform environment variables on the local environment:

    * TF_VAR_dp_account_number=*[account number of the environment to update]*

4. Initialize Terraform (if not done so previously):

```
[location of project] $ terraform init   
```
5. Run Terraform to view changes that will be made to the DP environment AWS resources

```
[location of project] $ terraform plan
```
6. Run `terraform fmt --recursive` to properly format your Terraform changes before pushing to a branch.

## Further Information

* Terraform website: https://www.terraform.io/
* Terraform basic tutorial: https://learn.hashicorp.com/terraform/getting-started/build
