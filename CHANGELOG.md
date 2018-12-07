# 6.3.2

BUGFIX:

- Give a useful error message if you try to run without Puppet private keys available.

# 6.3.1

BUGFIX:

- Remove cidr_ecosystem_dev/prd because they are breaking existing runs(in infraprd). Will enable again in the future once everyone is using 1.1.

# 6.3.0

FEATURES:

 - Exports TF_VARS based on the current directory
 - Update README
 - Simplify output. Remove default debug mode.
 - Doesn't delete cache folder

# 6.2.0

FEATURES:

- Set TF_VAR_product,ecosystem,envname
- Replace envname with env so we can transition to the new env name
- You can remove product,envname,ecosystem from your params/env.tfvars as they are now discovered from your directory structure
# 6.1.0

FEATURES:
  - added support for aws-assume-role with temporary STS credentials

REQUIRED CHANGES:

  - ruby > `v2.1`
  - added dependency on `aws-assume-role` Gem
  - please follow [setup instructions](https://github.com/ITV/cp-docs/wiki/howto:-AWS-Assume-Role)

# 6.0.0

BREAKING CHANGE:

  - Terraform 0.10.x support

REQUIRED CHANGES:

  - Add a block for the s3 backend in the `main.tf` (example from root-infra):
    ```
    terraform {
      backend "s3" {
        bucket         = "root-tfstate-infraprd"
        key            = "infraprd-terraform.tfstate"
        region         = "eu-west-1"
        dynamodb_table = "root-tfstate-infraprd"
      }
    }
    ```
  - Pin the providers to specific versions: (example from root-infra):
    ```
    provider "aws" {
      region = "${var.region}"
      version = "1.0.0"
    }

    provider "template" {
      version = "1.0.0"
    }

    provider "terraform" {
      version = "1.0.0"
    }
    ```

# 5.0.0

Update hiera to 3.x, required for projects which implement Puppet 5.x

# 4.0.0

Breaking change:

Ecosystem variable within the ITV yaml now needs to be a hash - the Terraform run will fail hard if the ecosystems are not set to a hash within the config

# 3.1.0

Added hiera-eyaml support.

This allows us to use encrypted Terraform variables via hiera lookups (the `hiera.yaml` is consumed).

It also allows us to decrypt and extract SSL certificates or SSH keys which can then be used as appropriate.

In order to utilise these two improvements, you must update your `itv.yaml` e.g.:

```
dome:
  hiera_keys:
    artifactory_password: 'deirdre::artifactory_password'
  certs:
    sit.phoenix.itv.com.pem: 'phoenix::sit_wildcard_cert'
    phoenix.key: 'phoenix::certificate_key'
```

This release also containes:
- Improved debugging/output messages.
- More tests.

# 3.0.1

Forcibly unsetting environment variables `AWS_ACCESS_KEY` and `AWS_SECRET_KEY`.
This is to prevent bypassing the user's local credentials specified in `~/.aws/credentials`.

Fixed bug where `dome --state` needed to be called first when setting up a new environment.
This requires some further testing but we may wish to remove this CLI option in the future.

# 3.0.0

Thanks to [@Russell-IO](https://github.com/Russell-IO) for helping with these changes.

- Internal refactoring.
- More tests added (but lots more needed).
- Improved debug output and explained up front how variables are set.
- Removed `aws_profile_parser` and used environment variables instead to unify
the AWS CLI and terraform calls.

ROADMAP:
- Merge [@mhlias](https://github.com/mhlias) changes that implements assumed-role support.
