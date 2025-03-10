# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require 'timecop'
require_relative '../../lib/sampler/fallback_sampler'

class TestFallbackSampler < Minitest::Test
  def setup
    @current_time = Time.now
    Timecop.freeze(@current_time)
  end

  def teardown
    Timecop.return
  end

  def test_should_sample
    sampler = FallbackSampler.new

    sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, [])

    # 0 seconds passed, 0 quota available
    sampled = 0
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    # 0.4 seconds passed, 0.4 quota available
    sampled = 0
    Timecop.freeze(@current_time + 0.4)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    # 0.8 seconds passed, 0.8 quota available
    sampled = 0
    Timecop.freeze(@current_time + 0.8)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    # 1.2 seconds passed, 1 quota consumed, 0 quota available
    sampled = 0
    Timecop.freeze(@current_time + 1.2)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 1, sampled

    # 1.6 seconds passed, 0.4 quota available
    sampled = 0
    Timecop.freeze(@current_time + 1.6)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    # 2.0 seconds passed, 0.8 quota available
    sampled = 0
    Timecop.freeze(@current_time + 2.0)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    # 2.4 seconds passed, one more quota consumed, 0 quota available
    sampled = 0
    Timecop.freeze(@current_time + 2.4)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 1, sampled

    # 100 seconds passed, only one quota can be consumed
    sampled = 0
    Timecop.freeze(@current_time + 100)
    30.times do
      if sampler.should_sample(Context.active, '1234', 'name', SpanKind::CLIENT, {}, []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 1, sampled
  end

  def test_to_string
    assert_equal(
      'FallbackSampler{fallback sampling with sampling config of 1 req/sec and 5% of additional requests}',
      FallbackSampler.new.to_s
    )
  end
end



=begin



Key changes made in the conversion:

    Used Ruby's MiniTest framework instead of Jest
    Replaced Sinon's fake timers with Ruby's Timecop gem for time manipulation
    Changed the test class structure to follow Ruby conventions
    Used setup and teardown methods instead of beforeEach and afterEach
    Converted JavaScript-style loops to Ruby's block syntax
    Used Ruby's assertion methods instead of Jest's expect syntax
    Changed camelCase to snake_case for Ruby conventions
    Assumed the existence of corresponding Ruby implementations for:
        Context
        SpanKind
        SamplingDecision
        FallbackSampler

Note: This conversion assumes you have the necessary Ruby implementations of the OpenTelemetry classes and constants. You'll need to ensure these implementations exist and match the expected interface. The Timecop gem should be added to your project's dependencies for time manipulation in tests.


=end