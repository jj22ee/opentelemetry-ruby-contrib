# frozen_string_literal: true

# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry/sdk'
require 'date'
require_relative 'sampling_rule'
require_relative 'statistics'
require_relative 'rate_limiting_sampler'
require_relative 'utils'

# Constants to mirror the TypeScript semantic conventions
SEMATTRS_AWS_LAMBDA_INVOKED_ARN = 'aws.lambda.invoked_arn'
SEMATTRS_HTTP_HOST = 'http.host'
SEMATTRS_HTTP_METHOD = 'http.method'
SEMATTRS_HTTP_TARGET = 'http.target'
SEMATTRS_HTTP_URL = 'http.url'
SEMRESATTRS_CLOUD_PLATFORM = 'cloud.platform'
SEMRESATTRS_SERVICE_NAME = 'service.name'

ATTR_URL_PATH = 'url.path'
ATTR_URL_FULL = 'url.full'
ATTR_HTTP_REQUEST_METHOD = 'http.request.method'
ATTR_SERVER_ADDRESS = 'server.address'
ATTR_CLIENT_ADDRESS = 'client.address'

SEMRESATTRS_AWS_ECS_CONTAINER_ARN = 'aws.ecs.container.arn'
SEMRESATTRS_AWS_ECS_CLUSTER_ARN = 'aws.ecs.cluster.arn'
SEMRESATTRS_AWS_EKS_CLUSTER_ARN = 'aws.eks.cluster.arn'
SEMRESATTRS_CLOUD_PLATFORM = 'cloud.platform'
CLOUDPLATFORMVALUES_AWS_LAMBDA = 'aws.lambda'
SEMRESATTRS_FAAS_ID = 'faas.id'
SEMATTRS_AWS_LAMBDA_INVOKED_ARN = 'aws.lambda.invoked.arn'

# Constants would typically be defined in a separate configuration or constants file
MAX_DATE_TIME_SECONDS = Time.at(8_640_000_000_000)

module OpenTelemetry
  module Sampler
    module XRay
      class SamplingRuleApplier
        attr_reader :sampling_rule

        def initialize(sampling_rule, statistics = OpenTelemetry::Sampler::XRay::Statistics.new, target = nil)
          @sampling_rule = sampling_rule
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
          http_target = nil
          http_url = nil
          http_method = nil
          http_host = nil

          if !attributes.nil?
            http_target = attributes[SEMATTRS_HTTP_TARGET] || attributes[ATTR_URL_PATH]
            http_url = attributes[SEMATTRS_HTTP_URL] || attributes[ATTR_URL_FULL]
            http_method = attributes[SEMATTRS_HTTP_METHOD] || attributes[ATTR_HTTP_REQUEST_METHOD]
            http_host = attributes[SEMATTRS_HTTP_HOST] || attributes[ATTR_SERVER_ADDRESS] || attributes[ATTR_CLIENT_ADDRESS]
          end

          service_type = nil
          resource_arn = nil

          resource_hash = resource.attribute_enumerator.to_h

          if resource
            service_name = resource_hash[SEMRESATTRS_SERVICE_NAME] || ''
            cloud_platform = resource_hash[SEMRESATTRS_CLOUD_PLATFORM]
            service_type = OpenTelemetry::Sampler::XRay::Utils::CLOUD_PLATFORM_MAPPING[cloud_platform] if cloud_platform.is_a?(String)
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

          OpenTelemetry::Sampler::XRay::Utils::attribute_match(attributes, @sampling_rule.attributes) &&
            OpenTelemetry::Sampler::XRay::Utils::wildcard_match(@sampling_rule.host, http_host) &&
            OpenTelemetry::Sampler::XRay::Utils::wildcard_match(@sampling_rule.http_method, http_method) &&
            OpenTelemetry::Sampler::XRay::Utils::wildcard_match(@sampling_rule.service_name, service_name) &&
            OpenTelemetry::Sampler::XRay::Utils::wildcard_match(@sampling_rule.url_path, http_target) &&
            OpenTelemetry::Sampler::XRay::Utils::wildcard_match(@sampling_rule.service_type, service_type) &&
            OpenTelemetry::Sampler::XRay::Utils::wildcard_match(@sampling_rule.resource_arn, resource_arn)
        end

        def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
          has_borrowed = false
          result = OpenTelemetry::SDK::Trace::Samplers::Result.new(
            decision: OpenTelemetry::SDK::Trace::Samplers::Decision::DROP,
            tracestate: OpenTelemetry::Trace::Tracestate::DEFAULT
          )

          now = Time.now
          reservoir_expired = now >= @reservoir_expiry_time

          unless reservoir_expired
            result = @reservoir_sampler.should_sample?(
              trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes
            )
            has_borrowed = @borrowing_enabled && result.instance_variable_get(:@decision) != OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
          end

          if result.instance_variable_get(:@decision) == OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
            result = @fixed_rate_sampler.should_sample?(
              trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes
            )
          end

          @statistics_lock.synchronize {
            @statistics.sample_count += result.instance_variable_get(:@decision) != OpenTelemetry::SDK::Trace::Samplers::Decision::DROP ? 1 : 0
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

          if target["ReservoirQuota"]
            @reservoir_sampler = OpenTelemetry::Sampler::XRay::RateLimitingSampler.new(target["ReservoirQuota"])
          end

          @reservoir_expiry_time = if target["ReservoirQuotaTTL"]
                                    Time.at(target["ReservoirQuotaTTL"])
                                  else
                                    Time.now
                                  end

          if target["FixedRate"]
            @fixed_rate_sampler = OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(target["FixedRate"])
          end
        end

        def get_arn(resource, attributes)
          resource_hash = resource.attribute_enumerator.to_h
          arn = resource_hash[SEMRESATTRS_AWS_ECS_CONTAINER_ARN] ||
                resource_hash[SEMRESATTRS_AWS_ECS_CLUSTER_ARN] ||
                resource_hash[SEMRESATTRS_AWS_EKS_CLUSTER_ARN]

          if arn.nil? && resource_hash[SEMRESATTRS_CLOUD_PLATFORM] == CLOUDPLATFORMVALUES_AWS_LAMBDA
            arn = get_lambda_arn(resource, attributes)
          end
          arn
        end

        def get_lambda_arn(resource, attributes)
          resource_hash = resource.attribute_enumerator.to_h
          resource_hash[SEMRESATTRS_FAAS_ID] || attributes[SEMATTRS_AWS_LAMBDA_INVOKED_ARN]
        end
      end
    end
  end
end
