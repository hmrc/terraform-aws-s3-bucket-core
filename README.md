# S3 bucket core module

This module enforces some of the PlatSec S3 bucket policy. As the bucket and kms key policies need to be provided, the user of
this module will be responsible for ensuring the bucket created with this module complies with the policy.

There is a [standard bucket module](https://github.com/hmrc/terraform-aws-s3-bucket-standard) that will comply with the
policy while also requiring that no S3 permissions need to be managed.


## Policy enforcement

#### Logging
**S3 server access logging is enabled.** The target bucket must be supplied with variable `log_bucket_id`. The logs for
this bucket will be stored with the prefix <account_id>/<bucket_name>

#### Bucket policy

**Public access is blocked.**

#### Tagging

**`data_sensitivity` tag will be set to either "high" or "low".** Set with the variable `data_sensitivity` (default
"low"). For buckets with PII or other sensitive data, the tag **must** be "high".

**`data_expiry` tag will be added - see Life cycle policies below.**

#### Versioning

In order to ensure that data is not accidentally lost, versioning **should** be enabled. Versioning is controlled by
the variable `versioning_enabled` which defaults to `true`.

**Version expiration is enabled for non-current entries and is set to 90 days.**

#### Life cycle policies

One of the following data_expiry values must be chosen. The bucket tag `data_expiry` will be set to the value chosen
and a lifecycle rule added to ensure data expires after the appropriate number of days.

 | Tag Values | Expiration |
|------------|------------|
| 1-day      | 1 day      |
| 1-week     | 7 days     |
| 1-month    | 31 days    |
| 90-days    | 90 days    |
| 6-months   | 183 days   |
| 1-year     | 366 days   |
| 7-years    | 2557 days  |
| 10-years   | 3653 days  |

#### Encryption at rest, Key management service

The bucket will be encrypted with a KMS key created by this module, but the KMS policy must be supplied with the
`kms_key_policy` variable (sting of JSON).

**KMS key rotation is enabled.**

#### Access control list (ACL)

Bucket ownership controls are set to `BucketOwnerEnforced` which means that bucket ACLs have no effect (equivalent to
the default "private")

## Tests

### How to use / run tests
In order to integrate with AWS, we need to provide the relevant credentials.
This is done through passing AWS environment variables to the docker container and then, depending on your AWS config set up,
you will need to run the following command in order to pass the credentials through to terraform:

AWS Vault

```aws-vault exec <role> -- make test ```

AWS Profile

``` aws-profile -p <role> make test ```
