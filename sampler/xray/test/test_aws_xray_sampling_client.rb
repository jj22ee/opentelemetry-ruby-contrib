# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../../lib/sampler/aws_xray_sampling_client'
require_relative '../../lib/logger/diag_console_logger'

class TestAwsXraySamplingClient < Minitest::Test
  DATA_DIR = File.join(__dir__, 'data')
  TEST_URL = 'http://127.0.0.1:2000'

  def setup
    @logger = DiagConsoleLogger.new
  end

  def test_get_no_sampling_rules
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: { SamplingRuleRecords: [] }.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_rules do |response|
      assert_equal 0, response[:SamplingRuleRecords]&.length
    end
  end

  def test_get_invalid_response
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: {}.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_rules do |response|
      assert_nil response[:SamplingRuleRecords]&.length
    end
  end

  def test_get_sampling_rule_missing_in_records
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: { SamplingRuleRecords: [{}] }.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_rules do |response|
      assert_equal 1, response[:SamplingRuleRecords]&.length
    end
  end

  def test_default_values_used_when_missing_properties_in_sampling_rule
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: { SamplingRuleRecords: [{ SamplingRule: {} }] }.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_rules do |response|
      assert_equal 1, response[:SamplingRuleRecords]&.length
      rule = response[:SamplingRuleRecords]&.first[:SamplingRule]
      refute_nil rule
      assert_nil rule[:Attributes]
      assert_nil rule[:FixedRate]
      assert_nil rule[:HTTPMethod]
      assert_nil rule[:Host]
      assert_nil rule[:Priority]
      assert_nil rule[:ReservoirSize]
      assert_nil rule[:ResourceARN]
      assert_nil rule[:RuleARN]
      assert_nil rule[:RuleName]
      assert_nil rule[:ServiceName]
      assert_nil rule[:ServiceType]
      assert_nil rule[:URLPath]
      assert_nil rule[:Version]
    end
  end

  def test_get_correct_number_of_sampling_rules
    data = JSON.parse(File.read("#{DATA_DIR}/get-sampling-rules-response-sample.json"))
    records = data['SamplingRuleRecords']

    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: data.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_rules do |response|
      assert_equal records.length, response[:SamplingRuleRecords]&.length
      
      records.each_with_index do |record, i|
        response_rule = response[:SamplingRuleRecords][i][:SamplingRule]
        record_rule = record['SamplingRule']
        
        assert_equal record_rule['Attributes'], response_rule[:Attributes]
        assert_equal record_rule['FixedRate'], response_rule[:FixedRate]
        assert_equal record_rule['HTTPMethod'], response_rule[:HTTPMethod]
        assert_equal record_rule['Host'], response_rule[:Host]
        assert_equal record_rule['Priority'], response_rule[:Priority]
        assert_equal record_rule['ReservoirSize'], response_rule[:ReservoirSize]
        assert_equal record_rule['ResourceARN'], response_rule[:ResourceARN]
        assert_equal record_rule['RuleARN'], response_rule[:RuleARN]
        assert_equal record_rule['RuleName'], response_rule[:RuleName]
        assert_equal record_rule['ServiceName'], response_rule[:ServiceName]
        assert_equal record_rule['ServiceType'], response_rule[:ServiceType]
        assert_equal record_rule['URLPath'], response_rule[:URLPath]
        assert_equal record_rule['Version'], response_rule[:Version]
      end
    end
  end

  def test_get_sampling_targets
    data = JSON.parse(File.read("#{DATA_DIR}/get-sampling-targets-response-sample.json"))

    stub_request(:post, "#{TEST_URL}/SamplingTargets")
      .to_return(status: 200, body: data.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_targets(data) do |response|
      assert_equal 2, response[:SamplingTargetDocuments].length
      assert_equal 0, response[:UnprocessedStatistics].length
      assert_equal 1707551387, response[:LastRuleModification]
    end
  end

  def test_get_invalid_sampling_targets
    data = {
      LastRuleModification: nil,
      SamplingTargetDocuments: nil,
      UnprocessedStatistics: nil
    }

    stub_request(:post, "#{TEST_URL}/SamplingTargets")
      .to_return(status: 200, body: data.to_json)

    client = AwsXraySamplingClient.new(TEST_URL, @logger)

    client.fetch_sampling_targets(data) do |response|
      assert_nil response[:SamplingTargetDocuments]
      assert_nil response[:UnprocessedStatistics]
      assert_nil response[:LastRuleModification]
    end
  end
end


=begin

Key changes made in the conversion:

    Used Ruby's MiniTest framework instead of Jest
    Replaced nock with webmock for HTTP request stubbing
    Changed expect() assertions to MiniTest assertions
    Converted camelCase to snake_case for Ruby conventions
    Used Ruby symbols instead of JavaScript object properties where appropriate
    Replaced TypeScript type annotations with Ruby's implicit typing
    Used Ruby's block syntax instead of JavaScript callbacks
    Used Ruby's file handling for reading JSON files
    Implemented proper Ruby class structure with setup method
    Used Ruby's string interpolation instead of JavaScript string concatenation

Note: This conversion assumes the existence of corresponding Ruby implementations of the AWS X-Ray sampling client and related classes. You'll need to ensure those implementations exist and match the expected interface.





=end