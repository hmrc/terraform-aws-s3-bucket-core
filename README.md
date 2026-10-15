# S3 bucket core module

This module enforces some of the MDTP PlatSec S3 bucket policy. As the bucket and kms key policies need to be provided,
the user of this module will be responsible for ensuring the bucket created with this module complies with the policy.

There is a [standard bucket module](https://registry.terraform.io/modules/hmrc/s3-bucket-standard/aws/latest) that will
comply with the policy while also requiring that no S3 permissions need to be managed.

## Policy enforcement

### Logging

**S3 server access logging is enabled.** The target bucket must be supplied with variable `log_bucket_id`. The logs for
this bucket will be stored with the prefix <account_id>/<bucket_name>

### Bucket policy

**Public access is blocked.**

### Tagging

**`data_sensitivity` tag will be set to either "high" or "low".** Set with the variable `data_sensitivity` (default
"low"). For buckets with PII or other sensitive data, the tag **must** be "high".

**`data_expiry` tag will be added - see Life cycle policies below.**

### Versioning

In order to ensure that data is not accidentally lost, versioning **should** be enabled. Versioning is controlled by
the variable `versioning_enabled` which defaults to `true`.

**Version expiration is enabled for non-current entries and is set to 90 days.**

### Lifecycle policies

#### Data Expiration

One of the following data_expiry values must be chosen. The bucket tag `data_expiry` will be set to the value chosen
and a lifecycle rule added to ensure data expires after the appropriate number of days.  If setting to
`forever-config-only`, no current-object expiry will be set; noncurrent versions still expire after 90 days.

| Tag Values          | Expiration |
|---------------------|------------|
| 1-day               | 1 day      |
| 1-week              | 7 days     |
| 1-month             | 31 days    |
| 90-days             | 90 days    |
| 6-months            | 183 days   |
| 1-year              | 366 days   |
| 18-months           | 549 days   |
| 7-years             | 2557 days  |
| 10-years            | 3653 days  |
| forever-config-only | 0 days     |

#### Storage class transitions

Transitions are optional and apply to current objects only. All transition inputs default to `0` (disabled), so existing
callers retain their current behaviour, including any configured `transition_to_glacier_days` value. `STANDARD` is the
default storage class, not a lifecycle transition destination.

| Input | Destination | Default | Illustrative enabled value (days) |
|-------|-------------|---------|-----------------------------------|
| `transition_to_standard_ia_days` | `STANDARD_IA` | `0` | `30` |
| `transition_to_onezone_ia_days` | `ONEZONE_IA` | `0` | `30`, only for reproducible data |
| `transition_to_intelligent_tiering_days` | `INTELLIGENT_TIERING` | `0` | `30` |
| `transition_to_glacier_ir_days` | `GLACIER_IR` | `0` | `30` |
| `transition_to_glacier_days` (existing) | `GLACIER` | `0` | `90` |
| `transition_to_deep_archive_days` | `DEEP_ARCHIVE` | `0` | `180` |

Values are days **after object creation**, not days since the preceding transition. New inputs must be non-null,
non-negative whole numbers. Enabled `STANDARD_IA` and `ONEZONE_IA` transitions require at least 30 days; other new
destinations allow any positive whole number. Since `0` disables a transition, this interface cannot request a day-zero
transition. The illustrative values above are policy choices, not automatically enabled defaults or universal recommendations.

For example, use the module directly with a staged archive policy:

```hcl
module "archive_bucket" {
  # Evaluation only; pin the published release tag after release.
  source = "git::https://github.com/hmrc/terraform-aws-s3-bucket-core.git?ref=PSEC-2379"

  bucket_name      = "my-team-archive-bucket"
  data_sensitivity = "low"
  data_expiry      = "1-year"

  log_bucket_id  = var.log_bucket_id
  kms_key_policy = var.kms_key_policy

  transition_to_standard_ia_days  = 30
  transition_to_glacier_days      = 90
  transition_to_deep_archive_days = 180
}
```

The caller supplies an existing access-log bucket and a valid KMS key policy through `var.log_bucket_id` and
`var.kms_key_policy`. Omitted transition inputs default to `0` (disabled).

For a direct transition, set only the desired input, such as `transition_to_standard_ia_days = 30` or
`transition_to_deep_archive_days = 180`, and choose an appropriate `data_expiry` (still a required input).

S3 restricts transition combinations and minimum time in a storage class. This module validates individual new inputs;
it does not validate cross-input schedules or their interaction with expiration. Unsupported schedules are rejected by
the provider or S3. Follow the [S3 transition constraints](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html).

Consider retrieval latency, retrieval/transition charges and minimum billable storage durations before enabling a policy:
30 days for `STANDARD_IA`/`ONEZONE_IA`, 90 days for `GLACIER_IR`/`GLACIER`, and 180 days for `DEEP_ARCHIVE`.
For example, transitioning to `DEEP_ARCHIVE` at day 180 and expiring at day 200 incurs early-deletion charges.
`ONEZONE_IA` stores data in a single Availability Zone and is appropriate only when the data can be recreated.

By default, S3 does not transition objects smaller than 128 KB. Updating an older lifecycle configuration can adopt this
newer default, so review small-object behaviour before upgrading. See the [AWS transition documentation](https://docs.aws.amazon.com/AmazonS3/latest/API/API_Transition.html).

Transitions do not change the configured current-object expiration, 90-day noncurrent-version expiration,
seven-day incomplete-multipart-upload cleanup, encryption or Object Lock settings.

### Encryption at rest, Key management service

The bucket will be encrypted with either the AWS default encryption or a KMS key created by this module.
This is controlled by setting the `use_default_encryption` variable.
By default this var is set to 'False' and a KMS key is created. A KMS policy must be supplied with the
`kms_key_policy` variable (sting of JSON). 

**KMS key rotation is enabled and set to rotate every 90 days.** 
This can be changed with the `kms_rotation_period_in_days` variable and can be set to between 90 and 2560.

### Access control list (ACL)

Bucket ownership controls are set to `BucketOwnerEnforced` by default, which means that bucket ACLs have no effect (equivalent to
the default "private"). This can be overridden if necessary to facilitate certain behaviours, such as allowing CloudFront to deliver standard logs to the bucket,
but the default should be used whenever possible as it offers the best security position.

### Object Lock

**Turned off by default.** In order to turn it on set the `object_lock` variable to true, which then has the option of 
either using the `COMPLIANCE` or `GOVERNANCE` mode via the `object_lock_mode` variable. If the `object_lock_mode` is not 
set, it will use `COMPLIANCE` mode by default, which is stricter.

Once Object Lock is enabled, the objects will be locked by the same amount of time set by the `data_expiry` parameter for 
the bucket. However, **Please Note:** that the maximum length of time allowed for object lock is set as `1000` day as   
allowed by AWS. Therefore, when `data_expiry` is set to `forever-config-only` the lock is not forever, but for the 
maximum allowed of `1000` days.
