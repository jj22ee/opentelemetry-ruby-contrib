# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0


# The cache expires 1 hour after the last refresh time.
RULE_CACHE_TTL_MILLIS = 60 * 60 * 1000

# 10 second default sampling targets polling interval
DEFAULT_TARGET_POLLING_INTERVAL_SECONDS = 10

module OpenTelemetry
  module Sampler
    module XRay


class RuleCache
  def initialize(sampler_resource)
    @rule_appliers = []
    @sampler_resource = sampler_resource
    @last_updated_epoch_millis = Time.now.to_i * 1000
    @cache_lock = Mutex.new
  end

  def expired?
    now_in_millis = Time.now.to_i * 1000
    now_in_millis > @last_updated_epoch_millis + RULE_CACHE_TTL_MILLIS
  end

  def get_matched_rule(attributes)
    @rule_appliers.find do |rule|
      rule.matches?(attributes, @sampler_resource) || rule.sampling_rule.rule_name == 'Default'
    end
  end

  def update_rules(new_rule_appliers)
    old_rule_appliers_map = {}

    @cache_lock.synchronize {
      @rule_appliers.each do |rule|
        old_rule_appliers_map[rule.sampling_rule.rule_name] = rule
      end

      new_rule_appliers.each_with_index do |new_rule, index|
        rule_name_to_check = new_rule.sampling_rule.rule_name
        if old_rule_appliers_map.key?(rule_name_to_check)
          old_rule = old_rule_appliers_map[rule_name_to_check]
          if new_rule.sampling_rule.equals?(old_rule.sampling_rule)
            new_rule_appliers[index] = old_rule
          end
        end
      end

      @rule_appliers = new_rule_appliers
      sort_rules_by_priority
      @last_updated_epoch_millis = Time.now.to_i * 1000
    }
  end

  def create_sampling_statistics_documents(client_id)
    statistics_documents = []

    # maybe? @cache_lock.synchronize {
    @rule_appliers.each do |rule|
      statistics = rule.snapshot_statistics
      now_in_seconds = Time.now.to_i

      sampling_statistics_doc = {
        ClientID: client_id,
        RuleName: rule.sampling_rule.rule_name,
        Timestamp: now_in_seconds,
        RequestCount: statistics.request_count,
        BorrowCount: statistics.borrow_count,
        SampledCount: statistics.sample_count
      }

      statistics_documents << sampling_statistics_doc
    end

    statistics_documents
  end

  def update_targets(target_documents, last_rule_modification)
    min_polling_interval = nil
    next_polling_interval = DEFAULT_TARGET_POLLING_INTERVAL_SECONDS

    @cache_lock.synchronize {
      @rule_appliers.each_with_index do |rule, index|
        target = target_documents[rule.sampling_rule.rule_name]
        if target
          @rule_appliers[index] = rule.with_target(target)
          if target.interval
            if min_polling_interval.nil? || min_polling_interval > target.interval
              min_polling_interval = target.interval
            end
          end
        else
          OpenTelemetry.logger.debug('Invalid sampling target: missing rule name')
        end
      end

      next_polling_interval = min_polling_interval if min_polling_interval

      refresh_sampling_rules = last_rule_modification * 1000 > @last_updated_epoch_millis
      return [refresh_sampling_rules, next_polling_interval]
    }
  end

  private

  def sort_rules_by_priority
    @rule_appliers.sort! do |rule1, rule2|
      if rule1.sampling_rule.priority == rule2.sampling_rule.priority
        rule1.sampling_rule.rule_name < rule2.sampling_rule.rule_name ? -1 : 1
      else
        rule1.sampling_rule.priority - rule2.sampling_rule.priority
      end
    end
  end
end

    end
  end
end

=begin

Key changes made in the conversion:

    Used Ruby naming conventions (snake_case instead of camelCase)
    Changed TypeScript type annotations to Ruby syntax
    Converted private methods using the private keyword
    Changed boolean methods to use the Ruby convention of adding ? at the end
    Used Ruby's hash syntax instead of TypeScript object syntax
    Changed class property access to use instance variables with @
    Used Ruby's array and enumerable methods instead of TypeScript array methods
    Converted the diagnostic logging to use OpenTelemetry's Ruby SDK logger
    Used Ruby's Time class instead of Date.now()
    Removed explicit type declarations as Ruby is dynamically typed

Note that this conversion assumes the existence of of corresponding Ruby classes and modules for the dependencies (OpenTelemetry, SamplingRuleApplier, etc.). You'll need to ensure these dependencies are properly implemented in Ruby with matching interfaces.


=end