# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require_relative '../../lib/sampler/sampling_rule'

class TestSamplingRule < Minitest::Test
  def test_sampling_rule_equality
    rule = SamplingRule.new(
      attributes: { 'abc' => '123', 'def' => '4?6', 'ghi' => '*89' },
      fixed_rate: 0.11,
      http_method: 'GET',
      host: '*********',
      priority: 20,
      reservoir_size: 1,
      resource_arn: '*',
      rule_arn: 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
      rule_name: 'test',
      service_name: 'myServiceName',
      service_type: 'AWS::EKS::Container',
      url_path: '/helloworld',
      version: 1
    )

    rule_unordered_attributes = SamplingRule.new(
      attributes: { 'ghi' => '*89', 'abc' => '123', 'def' => '4?6' },
      fixed_rate: 0.11,
      http_method: 'GET',
      host: '*********',
      priority: 20,
      reservoir_size: 1,
      resource_arn: '*',
      rule_arn: 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
      rule_name: 'test',
      service_name: 'myServiceName',
      service_type: 'AWS::EKS::Container',
      url_path: '/helloworld',
      version: 1
    )

    rule_updated = SamplingRule.new(
      attributes: { 'ghi' => '*89', 'abc' => '123', 'def' => '4?6' },
      fixed_rate: 0.11,
      http_method: 'GET',
      host: '*********',
      priority: 20,
      reservoir_size: 1,
      resource_arn: '*',
      rule_arn: 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
      rule_name: 'test',
      service_name: 'myServiceName',
      service_type: 'AWS::EKS::Container',
      url_path: '/helloworld_new',
      version: 1
    )

    rule_updated_2 = SamplingRule.new(
      attributes: { 'abc' => '128', 'def' => '4?6', 'ghi' => '*89' },
      fixed_rate: 0.11,
      http_method: 'GET',
      host: '*********',
      priority: 20,
      reservoir_size: 1,
      resource_arn: '*',
      rule_arn: 'arn:aws:xray:us-east-1:999999999999:sampling-rule/test',
      rule_name: 'test',
      service_name: 'myServiceName',
      service_type: 'AWS::EKS::Container',
      url_path: '/helloworld',
      version: 1
    )

    assert_equal true, rule == rule_unordered_attributes
    assert_equal false, rule == rule_updated
    assert_equal false, rule == rule_updated_2
  end
end




=begin

Key changes made in the conversion:

    Changed from TypeScript/Jest to Ruby/MiniTest syntax
    Converted the class name to follow Ruby naming conventions (TestSamplingRule)
    Changed the test method name to follow Ruby conventions (test_sampling_rule_equality)
    Converted the object initialization syntax to Ruby style with symbol keys
    Changed the equality assertions to use MiniTest's assert_equal
    Assumed the SamplingRule class implements the == operator for comparison
    Changed camelCase to snake_case for Ruby conventions
    Used string keys for the attributes hash (Ruby typically uses string keys rather than symbols for external data)

Note: This assumes you have a corresponding SamplingRule class implementation in Ruby that matches the TypeScript version and implements the appropriate equality comparison method (==).




=end