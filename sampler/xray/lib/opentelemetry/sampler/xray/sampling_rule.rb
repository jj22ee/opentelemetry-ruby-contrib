# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Sampler
    module XRay

class SamplingRule
  attr_accessor :rule_name, :rule_arn, :priority, :reservoir_size, :fixed_rate,
                :service_name, :service_type, :host, :http_method, :url_path,
                :resource_arn, :attributes, :version

  def initialize(sampling_rule)
    # The AWS API docs mark `rule_name` as an optional field but in practice it seems to always be
    # present, and sampling targets could not be computed without it. For now provide an arbitrary fallback just in
    # case the AWS API docs are correct.
    @rule_name = sampling_rule["RuleName"] || 'Default'
    @rule_arn = sampling_rule["RuleARN"]
    @priority = sampling_rule["Priority"]
    @reservoir_size = sampling_rule["ReservoirSize"]
    @fixed_rate = sampling_rule["FixedRate"]
    @service_name = sampling_rule["ServiceName"]
    @service_type = sampling_rule["ServiceType"]
    @host = sampling_rule["Host"]
    @http_method = sampling_rule["HTTPMethod"]
    @url_path = sampling_rule["URLPath"]
    @resource_arn = sampling_rule["ResourceARN"]
    @version = sampling_rule["Version"]
    @attributes = sampling_rule["Attributes"]

    puts self.rule_name
    puts self.reservoir_size + 2
  end

  def equals?(other)
    attributes_equals = if @attributes.nil? || other.attributes.nil?
                         @attributes == other.attributes
                       else
                         attributes_equal?(other.attributes)
                       end

    @fixed_rate == other.fixed_rate &&
      @http_method == other.http_method &&
      @host == other.host &&
      @priority == other.priority &&
      @reservoir_size == other.reservoir_size &&
      @resource_arn == other.resource_arn &&
      @rule_arn == other.rule_arn &&
      @rule_name == other.rule_name &&
      @service_name == other.service_name &&
      @service_type == other.service_type &&
      @url_path == other.url_path &&
      @version == other.version &&
      attributes_equals
  end

  private

  def attributes_equal?(other_attributes)
    return false unless @attributes.length == other_attributes.length

    other_attributes.each do |key, value|
      return false unless @attributes.key?(key) && @attributes[key] == value
    end

    true
  end
end

    end
  end
end

=begin


Key changes made in the conversion:

    Used Ruby naming conventions (snake_case instead of PascalCase)
    Used Ruby's attr_accessor for property declarations
    Changed instance variables to use @ prefix
    Simplified the equals method by extracting attributes comparison logic into a separate private method
    Removed explicit type declarations since Ruby is dynamically typed
    Adjusted the attribute comparison logic to use Ruby's hash methods
    Used Ruby's nil instead of undefined
    Used Ruby's unless keyword where it makes the code more readable
    Removed interface implementation since Ruby doesn't have interfaces
    Used Ruby's implicit return in methods

The functionality remains the same as the TypeScript version, just expressed in idiomatic Ruby.

=end