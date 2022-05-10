package test

import (
	"context"
	"fmt"
	"log"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/aws/retry"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const region = "eu-west-2"

func TestDataExpiryPeriods(t *testing.T) {
	t.Parallel()
	var data = []struct {
		dataExpiry         string
		expectedExpiryDays int32
	}{
		{dataExpiry: "1-day", expectedExpiryDays: 1},
		{dataExpiry: "1-week", expectedExpiryDays: 7},
		{dataExpiry: "1-month", expectedExpiryDays: 31},
		{dataExpiry: "90-days", expectedExpiryDays: 90},
		{dataExpiry: "6-months", expectedExpiryDays: 183},
		{dataExpiry: "1-year", expectedExpiryDays: 366},
		{dataExpiry: "18-months", expectedExpiryDays: 549},
		{dataExpiry: "7-years", expectedExpiryDays: 2557},
		{dataExpiry: "10-years", expectedExpiryDays: 3653},
	}
	for _, d := range data {
		d := d
		t.Run(fmt.Sprintf("data_expiry %v", d.dataExpiry), func(t *testing.T) {
			t.Parallel()
			ctx := context.Background()

			tfVars := map[string]interface{}{
				"data_expiry": d.dataExpiry,
			}
			terraformOptions := copyTerraformAndReturnOptions(t, "examples/simple", tfVars)
			defer terraform.Destroy(t, terraformOptions)
			terraform.InitAndApply(t, terraformOptions)

			bucketName := terraform.Output(t, terraformOptions, "bucket_name")
			client := s3.NewFromConfig(CreateConfig(t, ctx))
			lcc, err := client.GetBucketLifecycleConfiguration(ctx, &s3.GetBucketLifecycleConfigurationInput{
				Bucket: &bucketName,
			})
			require.NoError(t, err)
			expiryRule := getLifecycleRuleById(lcc.Rules, "Expiration days")
			require.NotNil(t, expiryRule)
			assert.Equal(t, d.expectedExpiryDays, expiryRule.Expiration.Days)
			tagOut, err := client.GetBucketTagging(ctx, &s3.GetBucketTaggingInput{
				Bucket: &bucketName,
			})
			require.NoError(t, err)
			dataExpiryTagValue := getTagValueByName(tagOut.TagSet, "data_expiry")
			require.NotNil(t, dataExpiryTagValue)
			assert.Equal(t, d.dataExpiry, *dataExpiryTagValue)
		})
	}
}

func TestDataNoExpiryPeriod(t *testing.T) {
	t.Parallel()
	ctx := context.Background()

	tfVars := map[string]interface{}{
		"data_expiry": "forever-config-only",
	}
	terraformOptions := copyTerraformAndReturnOptions(t, "examples/simple", tfVars)
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	client := s3.NewFromConfig(CreateConfig(t, ctx))
	lcc, err := client.GetBucketLifecycleConfiguration(ctx, &s3.GetBucketLifecycleConfigurationInput{
		Bucket: &bucketName,
	})
	require.NoError(t, err)
	expiryRule := getLifecycleRuleById(lcc.Rules, "Expiration days")
	require.NotNil(t, expiryRule)

	assert.Nil(t, expiryRule.Expiration)
	tagOut, err := client.GetBucketTagging(ctx, &s3.GetBucketTaggingInput{
		Bucket: &bucketName,
	})
	require.NoError(t, err)
	dataExpiryTagValue := getTagValueByName(tagOut.TagSet, "data_expiry")
	require.NotNil(t, dataExpiryTagValue)
	assert.Equal(t, "forever-config-only", *dataExpiryTagValue)
}

func getLifecycleRuleById(rules []types.LifecycleRule, id string) *types.LifecycleRule {
	for _, rule := range rules {
		if *rule.ID == id {
			return &rule
		}
	}
	return nil
}

func getTagValueByName(tags []types.Tag, name string) *string {
	for _, tag := range tags {
		if *tag.Key == name {
			return tag.Value
		}
	}
	return nil
}

func CreateConfig(t *testing.T, ctx context.Context) aws.Config {
	cfg, Err := config.LoadDefaultConfig(
		ctx,
		config.WithRetryer(func() aws.Retryer {
			customRetry := retry.AddWithErrorCodes(retry.NewStandard(), "AccessDenied")
			customRetry = retry.AddWithMaxAttempts(customRetry, 7)
			return customRetry
		}),
		config.WithRegion(region),
	)
	require.NoError(t, Err)
	return cfg
}

func copyTerraformAndReturnOptions(t *testing.T, pathFromRootToSource string, additionalVars map[string]interface{}) *terraform.Options {
	testName := fmt.Sprintf("terratest-%s", strings.ToLower(random.UniqueId()))
	vars := map[string]interface{}{
		"test_name": testName,
	}
	for k, v := range additionalVars {
		vars[k] = v
	}
	return CopyTerraformAndReturnOptions(t, pathFromRootToSource, vars)
}

func CopyTerraformAndReturnOptions(t *testing.T, pathFromRootToSource string, vars map[string]interface{}) *terraform.Options {
	tempTestFolder := test_structure.CopyTerraformFolderToTemp(t, "..", pathFromRootToSource)
	log.Print(tempTestFolder)

	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: tempTestFolder,
		Vars:         vars,
	})
}
