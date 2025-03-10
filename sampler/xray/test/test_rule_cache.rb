# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require 'timecop'
require_relative '../../src/sampler/rule_cache'
require_relative '../../src/sampler/sampling_rule'
require_relative '../../src/sampler/sampling_rule_applier'

class RuleCacheTest < Minitest::Test
  def create_rule(name, priority, reservoir_size, fixed_rate)
    test_sampling_rule = {
      'RuleName' => name,
      'Priority' => priority,
      'ReservoirSize' => reservoir_size,
      'FixedRate' => fixed_rate,
      'ServiceName' => '*',
      'ServiceType' => '*',
      'Host' => '*',
      'HTTPMethod' => '*',
      'URLPath' => '*',
      'ResourceARN' => '*',
      'Version' => 1
    }
    SamplingRuleApplier.new(SamplingRule.new(test_sampling_rule))
  end

  def test_cache_updates_and_sorts_rules
    # Set up default rule in rule cache
    default_rule = create_rule('Default', 10000, 1, 0.05)
    cache = RuleCache.new(Resource.new({}))
    cache.update_rules([default_rule])

    # Expect default rule to exist
    assert_equal 1, cache.instance_variable_get(:@rule_appliers).length

    # Set up incoming rules
    rule1 = create_rule('low', 200, 0, 0.0)
    rule2 = create_rule('abc', 100, 0, 0.0)
    rule3 = create_rule('Abc', 100, 0, 0.0)
    rule4 = create_rule('ab', 100, 0, 0.0)
    rule5 = create_rule('A', 100, 0, 0.0)
    rule6 = create_rule('high', 10, 0, 0.0)
    rules = [rule1, rule2, rule3, rule4, rule5, rule6]

    cache.update_rules(rules)

    rule_appliers = cache.instance_variable_get(:@rule_appliers)
    assert_equal rules.length, rule_appliers.length
    assert_equal 'high', rule_appliers[0].sampling_rule.rule_name
    assert_equal 'A', rule_appliers[1].sampling_rule.rule_name
    assert_equal 'Abc', rule_appliers[2].sampling_rule.rule_name
    assert_equal 'ab', rule_appliers[3].sampling_rule.rule_name
    assert_equal 'abc', rule_appliers[4].sampling_rule.rule_name
    assert_equal 'low', rule_appliers[5].sampling_rule.rule_name
  end

  def test_rule_cache_expiration_logic
    Timecop.freeze(Time.now) do
      default_rule = create_rule('Default', 10000, 1, 0.05)
      cache = RuleCache.new(Resource.new({}))
      cache.update_rules([default_rule])

      Timecop.travel(2 * 60 * 60) # Travel 2 hours into the future
      assert cache.expired?
    end
  end

  def test_update_cache_with_only_one_rule_changed
    cache = RuleCache.new(Resource.new({}))
    rule1 = create_rule('rule_1', 1, 0, 0.0)
    rule2 = create_rule('rule_2', 10, 0, 0.0)
    rule3 = create_rule('rule_3', 100, 0, 0.0)
    rule_appliers = [rule1, rule2, rule3]

    cache.update_rules(rule_appliers)
    rule_appliers_copy = cache.instance_variable_get(:@rule_appliers).dup

    new_rule3 = create_rule('new_rule_3', 5, 0, 0.0)
    new_rule_appliers = [rule1, rule2, new_rule3]
    cache.update_rules(new_rule_appliers)

    current_appliers = cache.instance_variable_get(:@rule_appliers)
    assert_equal 3, current_appliers.length
    assert_equal 'rule_1', current_appliers[0].sampling_rule.rule_name
    assert_equal 'new_rule_3', current_appliers[1].sampling_rule.rule_name
    assert_equal 'rule_2', current_appliers[2].sampling_rule.rule_name

    assert_equal rule_appliers_copy[0], current_appliers[0]
    assert_equal rule_appliers_copy[1], current_appliers[2]
    refute_equal rule_appliers_copy[2], current_appliers[1]
  end

  def test_update_rules_removes_older_rule
    cache = RuleCache.new(Resource.new({}))
    assert_equal 0, cache.instance_variable_get(:@rule_appliers).length

    rule1 = create_rule('first_rule', 200, 0, 0.0)
    cache.update_rules([rule1])

    rule_appliers = cache.instance_variable_get(:@rule_appliers)
    assert_equal 1, rule_appliers.length
    assert_equal 'first_rule', rule_appliers[0].sampling_rule.rule_name

    replacement_rule1 = create_rule('second_rule', 200, 0, 0.0)
    cache.update_rules([replacement_rule1])

    rule_appliers = cache.instance_variable_get(:@rule_appliers)
    assert_equal 1, rule_appliers.length
    assert_equal 'second_rule', rule_appliers[0].sampling_rule.rule_name
  end

  def test_update_sampling_targets
    rule1 = create_rule('default', 10000, 1, 0.05)
    rule2 = create_rule('test', 20, 10, 0.2)
    cache = RuleCache.new(Resource.new({}))
    cache.update_rules([rule1, rule2])

    time = Time.now.to_i
    target1 = {
      'FixedRate' => 0.05,
      'Interval' => 15,
      'ReservoirQuota' => 1,
      'ReservoirQuotaTTL' => time + 10,
      'RuleName' => 'default'
    }
    target2 = {
      'FixedRate' => 0.15,
      'Interval' => 12,
      'ReservoirQuota' => 5,
      'ReservoirQuotaTTL' => time + 10,
      'RuleName' => 'test'
    }
    target3 = {
      'FixedRate' => 0.15,
      'Interval' => 3,
      'ReservoirQuota' => 5,
      'ReservoirQuotaTTL' => time + 10,
      'RuleName' => 'associated rule does not exist'
    }

    target_map = {
      'default' => target1,
      'test' => target2,
      'associated rule does not exist' => target3
    }

    refresh_sampling_rules, next_polling_interval = cache.update_targets(target_map, time - 10)
    refute refresh_sampling_rules
    assert_equal target2['Interval'], next_polling_interval

    rule_appliers = cache.instance_variable_get(:@rule_appliers)
    assert_equal 2, rule_appliers.length

    refresh_sampling_rules_after, _ = cache.update_targets(target_map, time + 1)
    assert refresh_sampling_rules_after
  end

  def test_get_all_statistics
    Timecop.freeze(Time.now) do
      rule1 = create_rule('test', 4, 2, 2.0)
      rule2 = create_rule('default', 5, 5, 5.0)

      cache = RuleCache.new(Resource::EMPTY)
      cache.update_rules([rule1, rule2])

      Timecop.travel(0.001) # Travel 1ms into the future

      client_id = '12345678901234567890abcd'
      statistics = cache.create_sampling_statistics_documents(client_id)

      expected_statistics = [
        {
          'ClientID' => client_id,
          'RuleName' => 'test',
          'Timestamp' => Time.now.to_i,
          'RequestCount' => 0,
          'BorrowCount' => 0,
          'SampledCount' => 0
        },
        {
          'ClientID' => client_id,
          'RuleName' => 'default',
          'Timestamp' => Time.now.to_i,
          'RequestCount' => 0,
          'BorrowCount' => 0,
          'SampledCount' => 0
        }
      ]

      assert_equal expected_statistics, statistics
    end
  end
end


=begin


This conversion makes several assumptions:

    The Ruby classes (RuleCache, SamplingRule, etc.)c.) have similar interfaces to their TypeScript counterparts
    The Ruby implementation uses instance variables with similar names (e.g., @rule_appliers instead of ruleAppliers)
    The Ruby classes follow Ruby naming conventions (snake_case instead of camelCase)
    The Resource class exists with similar functionality
    We're using Timecop for time manipulation instead of Sinon's fake timers

You'll need to:

    Install required gems:


gem install minitest
gem install timecop



    Ensure your Ruby implementation of the classes matches the expected interface
    Adjust the relative paths to match your project structure
    Modify assertions if the actual implementation details differ

The main differences from the TypeScript version are:

    Using Ruby's built-in Minitest framework instead of Jest
    Using Timecop for time manipulation
    Using Ruby's naming conventions
    Using Ruby's hash syntax
    Using Ruby's assertion methods
    Using Ruby's class and method definitions




=end