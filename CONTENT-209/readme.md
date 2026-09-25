The script is tailored strongly for the AWS cloud provider, with tight integration to specific services. It incorporates a basic Git flow (Feature branches merged into master).

How to tailor the script for your needs:

- Determine your Git flow and adjust branch references accordingly. The current setup merges local branches into master.

- Determine your Accounts/Regions strategy in your cloud provider. The current setup targets a single default region and is best suited for environments hosted within a single account.

- Adjust the "Common AWS services" section to configure your standard stack.

- Replace Terraform with your IaC framework of choice if different.

- Replace AWS with your cloud provider if different.

- Replace the variable placeholders with your actual values:

    {YOUR_SPECS_LOCATION} : Location of your specification files in the repository

    {YOUR_REPOSITORY_REF} : Reference link to your repository

    {YOUR_DEFAULT_REGION} : Default region you want to target

    {YOUR_LOCALSTACK_PATH} : Path to your LocalStack config file (if used)

    {YOUR_CLOUD_ENV_NAME} : Prefix for your cloud resources (applicable only if environments are identified by prefixes)

    {YOUR_SIBLINGS_CLOUD_ENV_NAME} : Prefix for sibling cloud resources (e.g., uat, applicable only if environments are identified by prefixes)