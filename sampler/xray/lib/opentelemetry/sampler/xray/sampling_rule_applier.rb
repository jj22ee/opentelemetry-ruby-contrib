# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry/sdk'
require 'date'
require_relative 'sampling_rule'
require_relative 'statistics'
require_relative 'rate_limiting_sampler'

# Constants would typically be defined in a separate configuration or constants file
MAX_DATE_TIME_SECONDS = Time.at(8_640_000_000_000)

module OpenTelemetry
  module Sampler
    module XRay


# OpenTelemetry::SemanticConventions::Trace::HTTP_TARGET

class SamplingRuleApplier
  attr_reader :sampling_rule

  def initialize(sampling_rule, statistics = OpenTelemetry::Sampler::XRay::Statistics.new, target = nil)
    @sampling_rule = OpenTelemetry::Sampler::XRay::SamplingRule.new(sampling_rule)
    @fixed_rate_sampler = OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(@sampling_rule.fixed_rate)

    @reservoir_sampler = if @sampling_rule.reservoir_size > 0
                          OpenTelemetry::Sampler::XRay::RateLimitingSampler.new(1)
                        else
                          OpenTelemetry::Sampler::XRay::RateLimitingSampler.new(0)
                        end

    @reservoir_expiry_time = MAX_DATE_TIME_SECONDS
    @statistics = statistics
    @statistics_lock = Mutex.new

    @statistics.reset_statistics
    @borrowing_enabled = true

    apply_target(target) if target
  end

  def with_target(target)
    self.class.new(@sampling_rule, @statistics, target)
  end

  def matches?(attributes, resource)
    http_target = attributes[SEMATTRS_HTTP_TARGET] || attributes[ATTR_URL_PATH]
    http_url = attributes[SEMATTRS_HTTP_URL] || attributes[ATTR_URL_FULL]
    http_method = attributes[SEMATTRS_HTTP_METHOD] || attributes[ATTR_HTTP_REQUEST_METHOD]
    http_host = attributes[SEMATTRS_HTTP_HOST] || attributes[ATTR_SERVER_ADDRESS] || attributes[ATTR_CLIENT_ADDRESS]

    service_type = nil
    resource_arn = nil

    if resource
      service_name = resource.attributes[SEMRESATTRS_SERVICE_NAME] || ''
      cloud_platform = resource.attributes[SEMRESATTRS_CLOUD_PLATFORM]
      service_type = CLOUD_PLATFORM_MAPPING[cloud_platform] if cloud_platform.is_a?(String)
      resource_arn = get_arn(resource, attributes)
    end

    # Handle URL parsing similar to TypeScript version
    if http_target.nil? && http_url.is_a?(String)
      begin
        uri = URI(http_url)
        http_target = uri.path.empty? ? '/' : uri.path
      rescue URI::InvalidURIError
        http_target = '/'
      end
    elsif http_target.nil? && http_url.nil?
      http_target = '/'
    end

    attribute_match(attributes, @sampling_rule.attributes) &&
      wildcard_match(@sampling_rule.host, http_host) &&
      wildcard_match(@sampling_rule.http_method, http_method) &&
      wildcard_match(@sampling_rule.service_name, service_name) &&
      wildcard_match(@sampling_rule.url_path, http_target) &&
      wildcard_match(@sampling_rule.service_type, service_type) &&
      wildcard_match(@sampling_rule.resource_arn, resource_arn)
  end

  def should_sample(context, trace_id, span_name, span_kind, attributes, links)
    has_borrowed = false
    result = { decision: OpenTelemetry::SDK::Trace::Samplers::Decision::DROP }

    now = Time.now
    reservoir_expired = now >= @reservoir_expiry_time

    unless reservoir_expired
      result = @reservoir_sampler.should_sample(context, trace_id, span_name, span_kind, attributes, links)
      has_borrowed = @borrowing_enabled && result[:decision] != OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
    end

    if result[:decision] == OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
      result = @fixed_rate_sampler.should_sample(context, trace_id)
    end

    @statistics_lock.synchronize {
      @statistics.sample_count += result[:decision] != OpenTelemetry::SDK::Trace::Samplers::Decision::DROP ? 1 : 0
      @statistics.borrow_count += has_borrowed ? 1 : 0
      @statistics.request_count += 1
    }

    result
  end

  def snapshot_statistics
    @statistics_lock.synchronize {
      statistics_copy = @statistics.dup
      @statistics.reset_statistics
      return statistics_copy
    }
  end

  private

  def apply_target(target)
    @borrowing_enabled = false

    if target.reservoir_quota
      @reservoir_sampler = OpenTelemetry::Sampler::XRay::RateLimitingSampler.new(target.reservoir_quota)
    end

    @reservoir_expiry_time = if target.reservoir_quota_ttl
                              Time.at(target.reservoir_quota_ttl)
                            else
                              Time.now
                            end

    if target.fixed_rate
      @fixed_rate_sampler = OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(target.fixed_rate)
    end
  end

  def get_arn(resource, attributes)
    arn = resource.attributes[SEMRESATTRS_AWS_ECS_CONTAINER_ARN] ||
          resource.attributes[SEMRESATTRS_AWS_ECS_CLUSTER_ARN] ||
          resource.attributes[SEMRESATTRS_AWS_EKS_CLUSTER_ARN]

    if arn.nil? && resource&.attributes[SEMRESATTRS_CLOUD_PLATFORM] == CLOUDPLATFORMVALUES_AWS_LAMBDA
      arn = get_lambda_arn(resource, attributes)
    end
    arn
  end

  def get_lambda_arn(resource, attributes)
    resource&.attributes[SEMRESATTRS_FAAS_ID] || attributes[SEMATTRS_AWS_LAMBDA_INVOKED_ARN]
  end
end


    end
  end
end



=begin


This Ruby conversion maintains the core functionality while adapting to Ruby's conventions and idioms. Key changes include:

    Using Ruby naming conventions (snake_case instead of camelCase)
    Converting TypeScript types to Ruby equivalents
    Using Ruby's attr_reader instead of public properties
    Implementing Ruby-style method naming (with question marks for boolean methods)
    Using Ruby's nil instead of undefined
    Converting JavaScript Date operations to Ruby Time operations
    Using Ruby's URI class instead of JavaScript's URL class

Note that this conversion assumes the existence of several supporting classes and constants that would need to be defined elsewhere (Statistics, SamplingRule, RateLimitingSampler, etc.). You would need to implement these classes and define the various constants (SEMATTRS_*, etc.) to make this code fully functional.

Also, the actual OpenTelemetry Ruby SDK might have different class names or methods than what's shown here, so you might need to adjust the code to match the actual Ruby OpenTelemetry SDK implementation.

=end