# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

# AwsXRayRemoteSamplerConfig class represents configuration for AWS X-Ray remote sampler
class AwsXRayRemoteSamplerConfig
  attr_accessor :resource, :endpoint, :polling_interval
end

# ISamplingRule represents an AWS X-Ray sampling rule
# https://docs.aws.amazon.com/xray/latest/api/API_SamplingRule.html
class ISamplingRule
  attr_accessor :rule_name, :rule_arn, :priority, :reservoir_size, :fixed_rate,
                :service_name, :service_type, :host, :http_method, :url_path,
                :resource_arn, :attributes, :version
end

# SamplingRuleRecord represents a sampling rule record
# https://docs.aws.amazon.com/xray/latest/api/API_SamplingRuleRecord.html
class SamplingRuleRecord
  attr_accessor :created_at, :modified_at, :sampling_rule
end

# GetSamplingRulesResponse represents the response from GetSamplingRules API
# https://docs.aws.amazon.com/xray/latest/api/API_GetSamplingRules.html#API_GetSamplingRules_ResponseSyntax
class GetSamplingRulesResponse
  attr_accessor :next_token, :sampling_rule_records
end

# ISamplingStatistics represents sampling statistics
class ISamplingStatistics
  attr_accessor :request_count, :sample_count, :borrow_count
end

# SamplingStatisticsDocument represents current state of sampling statistics
# https://docs.aws.amazon.com/xray/latest/api/API_GetSamplingTargets.html#API_GetSamplingTargets_RequestSyntax
class SamplingStatisticsDocument
  attr_accessor :client_id, :rule_name, :request_count, :borrow_count,
                :sampled_count, :timestamp
end

# SamplingTargetDocument represents a sampling target
# https://docs.aws.amazon.com/xray/latest/api/API_GetSamplingTargets.html#API_GetSamplingTargets_RequestBody
class SamplingTargetDocument
  attr_accessor :fixed_rate, :interval, :reservoir_quota,
                :reservoir_quota_ttl, :rule_name
end

# UnprocessedStatistic represents an unprocessed statistic
class UnprocessedStatistic
  attr_accessor :error_code, :message, :rule_name
end

# GetSamplingTargetsBody represents the request body for GetSamplingTargets API
class GetSamplingTargetsBody
  attr_accessor :sampling_statistics_documents
end

# GetSamplingTargetsResponse represents the response from GetSamplingTargets API
# https://docs.aws.amazon.com/xray/latest/api/API_GetSamplingTargets.html#API_GetSamplingTargets_ResponseSyntax
class GetSamplingTargetsResponse
  attr_accessor :last_rule_modification, :sampling_target_documents,
                :unprocessed_statistics
end

# TargetMap represents a map of target names to SamplingTargetDocument
class TargetMap
  def [](target_name)
    @targets[target_name]
  end

  def []=(target_name, value)
    @targets[target_name] = value
  end

  private

  def initialize
    @targets = {}
  end
end

=begin



Key changes made in the conversion:

    Changed TypeScript interfaces to Ruby classes
    Converted camelCase to snake_case to follow Ruby conventions
    Used attr_accessor for class attributes instead of TypeScript property definitions
    Implemented a basic Hash-like interface for the TargetMap class
    Removed explicit type annotations as Ruby is dynamically typed
    Maintained comments and documentation links for reference

The Ruby version maintains the same structure and functionality as the TypeScript code while following Ruby conventions and idioms. Each class can be instantiated and used similarly to how the TypeScript interfaces would be used, but with Ruby's object-oriented patterns.


=end