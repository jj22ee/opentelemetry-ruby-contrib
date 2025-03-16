

  

# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

# require 'opentelemetry/api'
require 'opentelemetry/sdk'
require_relative 'fallback_sampler'
require_relative 'sampling_rule_applier'
require_relative 'rule_cache'
require_relative 'aws_xray_sampling_client'
require 'net/http'
require 'json'

module OpenTelemetry
  module Sampler
    module XRay

    
# Constants
DEFAULT_RULES_POLLING_INTERVAL_SECONDS = 5 * 60
DEFAULT_TARGET_POLLING_INTERVAL_SECONDS = 10
DEFAULT_AWS_PROXY_ENDPOINT = 'http://localhost:2000'

# Wrapper class to ensure that all XRay Sampler Functionality in _AwsXRayRemoteSampler
# uses ParentBased logic to respect the parent span's sampling decision
class AwsXRayRemoteSampler
  def initialize(sampler_config)
    @root = ParentBasedSampler.new(root: _AwsXRayRemoteSampler.new(sampler_config))
  end

  def should_sample(context, trace_id, span_name, span_kind, attributes, links)
    @root.should_sample(context, trace_id, span_name, span_kind, attributes, links)
  end

  def to_s
    "AwsXRayRemoteSampler{root=#{@root}}"
  end
end



# _AwsXRayRemoteSampler contains all core XRay Sampler Functionality,
# however it is NOT Parent-based (e.g. Sample logic runs for each span)
class InternalAwsXRayRemoteSampler
  def initialize(endpoint: "127.0.0.1:2000", polling_interval: DEFAULT_RULES_POLLING_INTERVAL_SECONDS, resource: OpenTelemetry::SDK::Resources::Resource.create)

    if polling_interval.nil? || polling_interval < 10
      OpenTelemetry.logger.warn(
        "'polling_interval' is undefined or too small. Defaulting to #{DEFAULT_RULES_POLLING_INTERVAL_SECONDS} seconds"
      )
      @rule_polling_interval_millis = DEFAULT_RULES_POLLING_INTERVAL_SECONDS * 1000
    else
      @rule_polling_interval_millis = polling_interval * 1000
    end

    @rule_polling_jitter_millis = rand * 5 * 1000
    @target_polling_interval = get_default_target_polling_interval
    @target_polling_jitter_millis = (rand / 10) * 1000

    @aws_proxy_endpoint = endpoint || DEFAULT_AWS_PROXY_ENDPOINT
    @fallback_sampler = OpenTelemetry::Sampler::XRay::FallbackSampler.new
    @client_id = self.class.generate_client_id
    @rule_cache = OpenTelemetry::Sampler::XRay::RuleCache.new(resource)

    @sampling_client = OpenTelemetry::Sampler::XRay::AWSXRaySamplingClient.new(@aws_proxy_endpoint)

    # Start the Sampling Rules poller
    start_sampling_rules_poller

    # Start the Sampling Targets poller
    start_sampling_targets_poller
  end

  def get_default_target_polling_interval
    DEFAULT_TARGET_POLLING_INTERVAL_SECONDS
  end

  def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
    if @rule_cache.expired?
      OpenTelemetry.logger.debug('Rule cache is expired, so using fallback sampling strategy')
      return @fallback_sampler.should_sample?(
        trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes
      )
    end

    matched_rule = @rule_cache.get_matched_rule(attributes)
    if matched_rule
      return matched_rule.should_sample?(
        trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes
      )
    end

    OpenTelemetry.logger.debug(
      'Using fallback sampler as no rule match was found. This is likely due to a bug, since default rule should always match'
    )
    @fallback_sampler.should_sample?(
      trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes
    )
  end

  def to_s
    "_AwsXRayRemoteSampler{aws_proxy_endpoint=#{@aws_proxy_endpoint}, rule_polling_interval_millis=#{@rule_polling_interval_millis}}"
  end

  private

  def start_sampling_rules_poller
    # Execute first update
    sampling_rules_response = @sampling_client.fetch_sampling_rules
    if sampling_rules_response && sampling_rules_response.body && sampling_rules_response.body != ""
      rules = JSON.parse(sampling_rules_response.body)
      update_sampling_rules(rules)
    else
      OpenTelemetry.logger.error('GetSamplingRules Response is falsy')
    end

    # get_and_update_sampling_rules
    # Update sampling rules periodically
    @rule_poller = Thread.new do
      loop do
        sleep((@rule_polling_interval_millis + @rule_polling_jitter_millis) / 1000.0)
        # get_and_update_sampling_rules


        sampling_rules_response = @sampling_client.fetch_sampling_rules
        if sampling_rules_response && sampling_rules_response.body && sampling_rules_response.body != ""
          rules = JSON.parse(sampling_rules_response.body)
          update_sampling_rules(rules)
        else
          OpenTelemetry.logger.error('GetSamplingRules Response is falsy')
        end
      end
    end
  end

  def start_sampling_targets_poller
    @target_poller = Thread.new do
      loop do
        sleep((@target_polling_interval*1000 + @target_polling_jitter_millis) / 1000.0)
        # get_and_update_sampling_targets

        request_body = {
          SamplingStatisticsDocuments: @rule_cache.create_sampling_statistics_documents(@client_id)
        }

        sampling_targets_response = @sampling_client.fetch_sampling_targets(request_body)
        if sampling_targets_response && sampling_targets_response.body && sampling_targets_response.body != ""
          response_body = JSON.parse(sampling_targets_response.body)
          update_sampling_targets(response_body)
        else
          OpenTelemetry.logger.debug('SamplingTargets Response is falsy')
        end
      end
    end
  end

  def update_sampling_rules(response_object)
    sampling_rules = []
    if response_object && response_object["SamplingRuleRecords"]
      response_object["SamplingRuleRecords"].each do |record|
        if record["SamplingRule"]
          sampling_rule = OpenTelemetry::Sampler::XRay::SamplingRule.new(record["SamplingRule"])
          sampling_rules << SamplingRuleApplier.new(sampling_rule)
        end
      end
      @rule_cache.update_rules(sampling_rules)
    else
      OpenTelemetry.logger.error('SamplingRuleRecords from GetSamplingRules request is not defined')
    end
  end

  def update_sampling_targets(response_object)
    begin
      if response_object && response_object["SamplingTargetDocuments"]
        target_documents = {}

        response_object["SamplingTargetDocuments"].each do |new_target|
          target_documents[new_target["RuleName"]] = new_target
        end

        refresh_sampling_rules, next_polling_interval = @rule_cache.update_targets(
          target_documents,
          response_object["LastRuleModification"]
        )

        @target_polling_interval = next_polling_interval

        if refresh_sampling_rules
          OpenTelemetry.logger.debug('Performing out-of-band sampling rule polling to fetch updated rules.')
          @rule_poller.kill if @rule_poller
          start_sampling_rules_poller
        end
      else
        OpenTelemetry.logger.debug('SamplingTargetDocuments from SamplingTargets request is not defined')
      end
    rescue StandardError => e
      OpenTelemetry.logger.debug("Error occurred when updating Sampling Targets: #{e}")
    end
  end

  def self.generate_client_id
    hex_chars = ('0'..'9').to_a + ('a'..'f').to_a
    Array.new(24) { hex_chars.sample }.join
  end
end



    end
  end
end
=begin


Key changes made in the conversion:

    Used Ruby naming conventions (snake_case instead of camelCase)
    Replaced TypeScript types with Ruby's dynamic typing
    Converted JavaScript interval timers to Ruby threads with sleep
    Changed class methods to use self. prefix
    Converted array/object syntax to Ruby style
    Used Ruby symbol syntax for hash keys
    Replaced undefined checks with nil checks
    Used Ruby's block syntax for callbacks
    Implemented thread management instead of Node.js timer management
    Used Ruby's exception handling syntax

Note that this is a basic conversion and might need additional adjustments depending on the specific Ruby environment and requirements. Some features like the OpenTelemetry integration would need the appropriate Ruby gems and might have slightly different APIs than their TypeScript counterparts.


  
=end