

  

# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry/api'
require 'opentelemetry/sdk/trace/base'

# Constants
DEFAULT_RULES_POLLING_INTERVAL_SECONDS = 5 * 60
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
class _AwsXRayRemoteSampler
  def initialize(sampler_config)
    @sampler_diag = diag

    if sampler_config.polling_interval.nil? || sampler_config.polling_interval < 10
      @sampler_diag.warn(
        "'polling_interval' is undefined or too small. Defaulting to #{DEFAULT_RULES_POLLING_INTERVAL_SECONDS} seconds"
      )
      @rule_polling_interval_millis = DEFAULT_RULES_POLLING_INTERVAL_SECONDS * 1000
    else
      @rule_polling_interval_millis = sampler_config.polling_interval * 1000
    end

    @rule_polling_jitter_millis = rand * 5 * 1000
    @target_polling_interval = get_default_target_polling_interval
    @target_polling_jitter_millis = (rand / 10) * 1000

    @aws_proxy_endpoint = sampler_config.endpoint || DEFAULT_AWS_PROXY_ENDPOINT
    @fallback_sampler = FallbackSampler.new
    @client_id = self.class.generate_client_id
    @rule_cache = RuleCache.new(sampler_config.resource)

    @sampling_client = AwsXraySamplingClient.new(@aws_proxy_endpoint, @sampler_diag)

    # Start the Sampling Rules poller
    start_sampling_rules_poller

    # Start the Sampling Targets poller
    start_sampling_targets_poller
  end

  def get_default_target_polling_interval
    DEFAULT_TARGET_POLLING_INTERVAL_SECONDS
  end

  def should_sample(context, trace_id, span_name, span_kind, attributes, links)
    if @rule_cache.expired?
      @sampler_diag.debug('Rule cache is expired, so using fallback sampling strategy')
      return @fallback_sampler.should_sample(context, trace_id, span_name, span_kind, attributes, links)
    end

    matched_rule = @rule_cache.get_matched_rule(attributes)
    if matched_rule
      return matched_rule.should_sample(context, trace_id, span_name, span_kind, attributes, links)
    end

    @sampler_diag.debug(
      'Using fallback sampler as no rule match was found. This is likely due to a bug, since default rule should always match'
    )
    @fallback_sampler.should_sample(context, trace_id, span_name, span_kind, attributes, links)
  end

  def to_s
    "_AwsXRayRemoteSampler{aws_proxy_endpoint=#{@aws_proxy_endpoint}, rule_polling_interval_millis=#{@rule_polling_interval_millis}}"
  end

  private

  def start_sampling_rules_poller
    # Execute first update
    get_and_update_sampling_rules
    # Update sampling rules periodically
    @rule_poller = Thread.new do
      loop do
        sleep((@rule_polling_interval_millis + @rule_polling_jitter_millis) / 1000.0)
        get_and_update_sampling_rules
      end
    end
  end

  def start_sampling_targets_poller
    @target_poller = Thread.new do
      loop do
        sleep(@target_polling_interval + @target_polling_jitter_millis / 1000.0)
        get_and_update_sampling_targets
      end
    end
  end

  def get_and_update_sampling_targets
    request_body = {
      sampling_statistics_documents: @rule_cache.create_sampling_statistics_documents(@client_id)
    }

    @sampling_client.fetch_sampling_targets(request_body) { |response| update_sampling_targets(response) }
  end

  def get_and_update_sampling_rules
    @sampling_client.fetch_sampling_rules { |response| update_sampling_rules(response) }
  end

  def update_sampling_rules(response_object)
    sampling_rules = []
    if response_object[:sampling_rule_records]
      response_object[:sampling_rule_records].each do |record|
        if record[:sampling_rule]
          sampling_rules << SamplingRuleApplier.new(record[:sampling_rule], nil)
        end
      end
      @rule_cache.update_rules(sampling_rules)
    else
      @sampler_diag.error('SamplingRuleRecords from GetSamplingRules request is not defined')
    end
  end

  def update_sampling_targets(response_object)
    begin
      target_documents = {}

      response_object[:sampling_target_documents].each do |new_target|
        target_documents[new_target[:rule_name]] = new_target
      end

      refresh_sampling_rules, next_polling_interval = @rule_cache.update_targets(
        target_documents,
        response_object[:last_rule_modification]
      )
      
      @target_polling_interval = next_polling_interval
      @target_poller.kill if @target_poller
      start_sampling_targets_poller

      if refresh_sampling_rules
        @sampler_diag.debug('Performing out-of-band sampling rule polling to fetch updated rules.')
        @rule_poller.kill if @rule_poller
        start_sampling_rules_poller
      end
    rescue StandardError => e
      @sampler_diag.debug('Error occurred when updating Sampling Targets')
    end
  end

  def self.generate_client_id
    hex_chars = ('0'..'9').to_a + ('a'..'f').to_a
    Array.new(24) { hex_chars.sample }.join
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