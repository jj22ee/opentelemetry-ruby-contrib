# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require 'json'
require_relative '../../lib/sampler/sampling_rule'
require_relative '../../lib/sampler/sampling_rule_applier'

# Constants to mirror the TypeScript semantic conventions
SEMATTRS_AWS_LAMBDA_INVOKED_ARN = 'aws.lambda.invoked_arn'
SEMATTRS_HTTP_HOST = 'http.host'
SEMATTRS_HTTP_METHOD = 'http.method'
SEMATTRS_HTTP_TARGET = 'http.target'
SEMATTRS_HTTP_URL = 'http.url'
SEMRESATTRS_CLOUD_PLATFORM = 'cloud.platform'
SEMRESATTRS_SERVICE_NAME = 'service.name'

class TestSamplingRuleApplier < Minitest::Test
  DATA_DIR = File.join(File.dirname(__FILE__), 'data')

  def test_applier_attribute_matching_from_xray_response
    sample_data = JSON.parse(File.read(File.join(DATA_DIR, 'get-sampling-rules-response-sample-2.json')))

    all_rules = sample_data['SamplingRuleRecords']
    default_rule = SamplingRule.new(all_rules[0]['SamplingRule'])
    sampling_rule_applier = SamplingRuleApplier.new(default_rule)

    resource = Resource.new({
      SEMRESATTRS_SERVICE_NAME => 'test_service_name',
      SEMRESATTRS_CLOUD_PLATFORM => 'test_cloud_platform'
    })

    attr = {
      SEMATTRS_HTTP_TARGET => '/target',
      SEMATTRS_HTTP_METHOD => 'method',
      SEMATTRS_HTTP_URL => 'url',
      SEMATTRS_HTTP_HOST => 'host',
      'foo' => 'bar',
      'abc' => '1234'
    }

    assert sampling_rule_applier.matches?(attr, resource)
  end

  def test_applier_matches_with_all_attributes
    rule = SamplingRule.new({
      'Attributes' => { 'abc' => '123', 'def' => '4?6', 'ghi' => '*89' },
      'FixedRate' => 0.11,
      'HTTPMethod' => 'GET',
      'Host' => '*********',
      'Priority' => 20,
      'ReservoirSize' => 1,
      'ResourceARN' => 'arn:aws:lambda:us-west-2:123456789012:function:my-function',
      'RuleARN' => 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
      'RuleName' => 'test',
      'ServiceName' => 'myServiceName',
      'ServiceType' => 'AWS::Lambda::Function',
      'URLPath' => '/helloworld',
      'Version' => 1
    })

    attributes = {
      SEMATTRS_HTTP_HOST => '*********',
      SEMATTRS_HTTP_METHOD => 'GET',
      SEMATTRS_AWS_LAMBDA_INVOKED_ARN => 'arn:aws:lambda:us-west-2:123456789012:function:my-function',
      SEMATTRS_HTTP_URL => 'http://127.0.0.1:5000/helloworld',
      'abc' => '123',
      'def' => '456',
      'ghi' => '789'
    }

    resource = Resource.new({
      SEMRESATTRS_SERVICE_NAME => 'myServiceName',
      SEMRESATTRS_CLOUD_PLATFORM => 'aws_lambda'
    })

    rule_applier = SamplingRuleApplier.new(rule)

    assert rule_applier.matches?(attributes, resource)

    attributes.delete(SEMATTRS_HTTP_URL)
    attributes[SEMATTRS_HTTP_TARGET] = '/helloworld'
    assert rule_applier.matches?(attributes, resource)
  end

  def test_applier_wild_card_attributes_matches_span_attributes
    rule = SamplingRule.new({
      'Attributes' => {
        'attr1' => '*',
        'attr2' => '*',
        'attr3' => 'HelloWorld',
        'attr4' => 'Hello*',
        'attr5' => '*World',
        'attr6' => '?ello*',
        'attr7' => 'Hell?W*d',
        'attr8' => '*.World',
        'attr9' => '*.World'
      },
      'FixedRate' => 0.11,
      'HTTPMethod' => '*',
      'Host' => '*',
      'Priority' => 20,
      'ReservoirSize' => 1,
      'ResourceARN' => '*',
      'RuleARN' => 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
      'RuleName' => 'test',
      'ServiceName' => '*',
      'ServiceType' => '*',
      'URLPath' => '*',
      'Version' => 1
    })

    rule_applier = SamplingRuleApplier.new(rule)

    attributes = {
      'attr1' => '',
      'attr2' => 'HelloWorld',
      'attr3' => 'HelloWorld',
      'attr4' => 'HelloWorld',
      'attr5' => 'HelloWorld',
      'attr6' => 'HelloWorld',
      'attr7' => 'HelloWorld',
      'attr8' => 'Hello.World',
      'attr9' => 'Bye.World'
    }

    assert rule_applier.matches?(attributes, Resource::EMPTY)
  end

  def test_applier_wild_card_attributes_matches_http_span_attributes
    rule_applier = SamplingRuleApplier.new(
      SamplingRule.new({
        'Attributes' => {},
        'FixedRate' => 0.11,
        'HTTPMethod' => '*',
        'Host' => '*',
        'Priority' => 20,
        'ReservoirSize' => 1,
        'ResourceARN' => '*',
        'RuleARN' => 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
        'RuleName' => 'test',
        'ServiceName' => '*',
        'ServiceType' => '*',
        'URLPath' => '*',
        'Version' => 1
      })
    )

    attributes = {
      SEMATTRS_HTTP_HOST => '*********',
      SEMATTRS_HTTP_METHOD => 'GET',
      SEMATTRS_HTTP_URL => 'http://127.0.0.1:5000/helloworld'
    }

    assert rule_applier.matches?(attributes, Resource::EMPTY)
  end

  def test_applier_wild_card_attributes_matches_with_empty_attributes
    rule_applier = SamplingRuleApplier.new(
      SamplingRule.new({
        'Attributes' => {},
        'FixedRate' => 0.11,
        'HTTPMethod' => '*',
        'Host' => '*',
        'Priority' => 20,
        'ReservoirSize' => 1,
        'ResourceARN' => '*',
        'RuleARN' => 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
        'RuleName' => 'test',
        'ServiceName' => '*',
        'ServiceType' => '*',
        'URLPath' => '*',
        'Version' => 1
      })
    )

    attributes = {}
    resource = Resource.new({
      SEMRESATTRS_SERVICE_NAME => 'myServiceName',
      SEMRESATTRS_CLOUD_PLATFORM => 'aws_ec2'
    })

    assert rule_applier.matches?(attributes, resource)
    assert rule_applier.matches?({}, resource)
    assert rule_applier.matches?(attributes, Resource::EMPTY)
    assert rule_applier.matches?({}, Resource::EMPTY)
    assert rule_applier.matches?(attributes, Resource.new({}))
    assert rule_applier.matches?({}, Resource.new({}))
  end

  def test_applier_matches_with_http_url_with_http_target_undefined
    rule_applier = SamplingRuleApplier.new(
      SamplingRule.new({
        'Attributes' => {},
        'FixedRate' => 0.11,
        'HTTPMethod' => '*',
        'Host' => '*',
        'Priority' => 20,
        'ReservoirSize' => 1,
        'ResourceARN' => '*',
        'RuleARN' => 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
        'RuleName' => 'test',
        'ServiceName' => '*',
        'ServiceType' => '*',
        'URLPath' => '/somerandompath',
        'Version' => 1
      })
    )

    attributes = {
      SEMATTRS_HTTP_URL => 'https://somerandomurl.com/somerandompath'
    }
    resource = Resource.new({})

    assert rule_applier.matches?(attributes, resource)
    assert rule_applier.matches?(attributes, Resource::EMPTY)
    assert rule_applier.matches?(attributes, Resource.new({}))
  end
end



=begin



Key changes made in the conversion:

    Changed the test framework from Jest to MiniTest
    Converted describe and it blocks to test methods with snake_case naming
    Changed expect().toEqual() assertions to assert statements
    Converted TypeScript interfaces and types to Ruby classes
    Changed method naming to follow Ruby conventions (e.g., matches? instead of matches)
    Converted constant definitions to Ruby style
    Changed file path handling to use Ruby's File.join
    Adjusted JSON parsing to use Ruby's built-in JSON parser
    Changed class structure to inherit from Minitest::Test

Note: This conversion assumes the existence of corresponding Ruby classes (SamplingRule, SamplingRuleApplier, and Resource) with similar functionality to their TypeScript counterparts. You'll need to implement these classes separately.


=end