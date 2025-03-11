# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0


module OpenTelemetry
  module Sampler
    module XRay

# Note: These constants would typically come from a Ruby gem equivalent to @opentelemetry/semantic-conventions
CLOUD_PLATFORM_VALUES = {
  'aws_lambda' => 'AWS::Lambda::Function',
  'aws_elastic_beanstalk' => 'AWS::ElasticBeanstalk::Environment',
  'aws_ec2' => 'AWS::EC2::Instance',
  'aws_ecs' => 'AWS::ECS::Container',
  'aws_eks' => 'AWS::EKS::Container'
}.freeze

def escape_regexp(regexp_pattern)
  # Escapes special characters except * and ? to maintain wildcard functionality
  regexp_pattern.gsub(/[.+^${}()|[\]\\]/) { |match| "\\#{match}" }
end

def convert_pattern_to_regexp(pattern)
  escape_regexp(pattern).gsub(/\*/, '.*').gsub(/\?/, '.')
end

def wildcard_match(pattern = nil, text = nil)
  return true if pattern == '*'
  return false if pattern.nil? || !text.is_a?(String)
  return text.empty? if pattern.empty?

  regexp = "^#{convert_pattern_to_regexp(pattern.downcase)}$"
  match = text.downcase.match?(regexp)

  unless match
    # Assuming a logging mechanism exists
    puts "WildcardMatch: no match found for #{text} against pattern #{pattern}"
  end

  match
end

def attribute_match(attributes = nil, rule_attributes = nil)
  return true if rule_attributes.nil? || rule_attributes.empty?

  return false if attributes.nil? || 
                  attributes.empty? || 
                  rule_attributes.length > attributes.length

  matched_count = 0
  attributes.each do |key, value|
    found_key = rule_attributes.keys.find { |rule_key| rule_key == key }
    next if found_key.nil?

    matched_count += 1 if wildcard_match(rule_attributes[found_key], value)
  end

  matched_count == rule_attributes.length
end

    end
  end
end

=begin

Key differences and notes about the conversion:

    TypeScript types have been removed since Ruby is dynamically typed

    The CLOUD_PLATFORM_MAPPING has been renamed to CLOUD_PLATFORM_VALUES and simplified since Ruby doesn't need the complex TypeScript type definitions

    The escapeRegExp function has been converted to snake_case as escape_regexp to follow Ruby conventions

    Regular expressions in Ruby use slightly different syntax but maintain the same functionality

    The diag.debug call has been replaced with a simple puts for demonstration. In a real implementation, you'd want to use proper logging

    Ruby's match? method is used instead of JavaScript's match for better performance since we only care about whether there is a match, not the match data

    Method parameters use Ruby's optional parameter syntax with = nil instead of TypeScript's ?

    Object iteration uses Ruby's each method instead of JavaScript's Object.entries

    The .freeze is added to the constants hash to make it immutable

To use this code in a proper Ruby OpenTelemetry implementation, you'd need to:

    Add proper OpenTelemetry gem dependencies
    Replace the logging with proper OpenTelemetry logging mechanisms
    Potentially adjust the constant values to match the Ruby OpenTelemetry conventions


=end