# DR2 Terraform Environments

## Terraform Structure

The prototype is divided into separate files corresponding to one part of the infrastructure.
All of these files are run at once when terraform runs. 

`common.tf` Common modules like VPCs, shared security groups and system-wide secrets
`custodial_copy.tf` Shared resources for the custodial copy workflow.
`slack_notifications_lambda` Resources for the notifications lambda.
`deploy_preservica_config` A lambda, queue, topic and bucket for deploying XML config to Preservica.


## Deployment

To start a deployment, run the [DR2 Terraform Environments Deploy job in GitHub actions][github-actions-job] by clicking 'Run Workflow' and selecting the environment you want to deploy to. All changes must be deployed first to integration, then staging, then production.

The deployment will pause when Terraform has determined which changes need to be applied. Review the Terraform plan output by clicking the link provided in the Slack notification. This will be a link to Cloudwatch in the management account so you will need to be logged in to the management AWS account to use this.

Check whether the changes look correct, then open the actions approval page and accept or reject them. To find the actions approval page, follow the link from the Slack notification:

![Terraform deployment link in Slack](docs/images/slack-deployment-link.png)

Deployments can be approved by anyone in the `digital-records-repository` GitHub team.

[github-actions-job]: https://github.com/nationalarchives/dr2-terraform-environments/actions/workflows/apply.yml

## Elastic IPs
Each environment has one elastic IP per AZ created manually within the AWS console and then used within terraform using `data "aws_eip"`
This removes the risk of the EIP being accidentally deleted as this would change the IP address and we need a list of static IPs to send to Preservica.

## Local development

### Install Terraform locally

See: https://learn.hashicorp.com/terraform/getting-started/install.html

### Install AWS CLI Locally

See: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

### Install Terraform Plugins on Intellij

HCL Language Support: https://plugins.jetbrains.com/plugin/7808-hashicorp-terraform--hcl-language-support

## Running Terraform Project Locally

**NOTE: Running Terraform locally should only be used to check the Terraform plan. Updating the DR2 environments should only ever be done through GitHub actions**

1. Clone DR2 Environments project to local machine: https://github.com/nationalarchives/dr2-terraform-environments and navigate to the directory

2. Switch to the Terraform workspace corresponding to the DR2 environment to be worked on:

   ```
   [location of project] $ terraform workspace select intg
   ```

3. Set the following Terraform environment variables on the local environment:

    * TF_VAR_account_number=*[account number of the environment to update]*

4. Initialize Terraform (if not done so previously):

   ```
   [location of project] $ terraform init
   ```

5. To ensure the modules are up-to-date, run
   ```
   [location of project] $ terraform get -update
   ```

6. Make your terraform changes
   1. Add/update a tf file to the root of this project (might be best to copy an existing tf file as a base)
      * If you are creating a Lambda, add its arn to the `deploy_lambda_policy` in the `deploy_roles` file at the root of this project
   2. Add/update an IAM policy, depending on the change you are making
   3. If what you've created is part of a step function (e.g. a lambda):
      1. add it to the step function's module in the `common.tf`
      2. add it to the step function's policy module in the `common.tf`
      3. add it to the step function's `json.tpl` file in the `iam_policy` folder
      4. add it to the step function's `json.tpl` file in the `sfn` folder
   4. If item created needs a KMS key, add it to the `dr2_kms_key` module in the `common.tf` file
   5. If this is a lambda which needs to be added to the ingest dashboard, add the lambda name to `local.dashboard_lambdas` in `common.tf`

7. Run Terraform to view changes that will be made to the DR2 environment AWS resources
    * Make sure your credentials are valid
      * If you have the AWS CLI installed, run `aws sso login --profile [account name where credentials are] && export AWS_PROFILE=[account name where credentials are]`
   ```
   [location of project] $ terraform plan
   ```

8. Run `terraform fmt --recursive` to properly format your Terraform changes before pushing to a branch.

## Further Information

* Terraform website: https://www.terraform.io/
* Terraform basic tutorial: https://learn.hashicorp.com/terraform/getting-started/build
