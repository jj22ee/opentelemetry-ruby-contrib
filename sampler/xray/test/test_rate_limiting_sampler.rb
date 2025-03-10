
# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require 'timecop'
require_relative '../../lib/sampler/rate_limiting_sampler'

class RateLimitingSamplerTest < Minitest::Test
  def setup
    @current_time = Time.now
    Timecop.freeze(@current_time)
  end

  def teardown
    Timecop.return
  end

  def test_should_sample
    sampler = RateLimitingSampler.new(30)

    sampled = 0
    100.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    Timecop.travel(@current_time + 0.5) # Move forward half a second

    sampled = 0
    100.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 15, sampled

    Timecop.travel(@current_time + 1.5) # Move forward 1 second

    sampled = 0
    100.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 30, sampled

    Timecop.travel(@current_time + 4) # Move forward 2.5 more seconds

    sampled = 0
    100.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 30, sampled

    Timecop.travel(@current_time + 1000) # Move forward 1000 seconds

    sampled = 0
    100.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 30, sampled
  end

  def test_should_sample_with_quota_of_one
    sampler = RateLimitingSampler.new(1)

    sampled = 0
    50.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    Timecop.travel(@current_time + 0.5) # Move forward half a second

    sampled = 0
    50.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 0, sampled

    Timecop.travel(@current_time + 1) # Move forward another half second

    sampled = 0
    50.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 1, sampled

    Timecop.travel(@current_time + 1000) # Move forward 1000 seconds

    sampled = 0
    50.times do
      if sampler.should_sample(context: Context.active, 
                             trace_id: '1234', 
                             name: 'name', 
                             kind: SpanKind::CLIENT, 
                             attributes: {}, 
                             links: []).decision != SamplingDecision::NOT_RECORD
        sampled += 1
      end
    end
    assert_equal 1, sampled
  end

  def test_to_string
    assert_equal(
      'RateLimitingSampler{rate limiting sampling with sampling config of 123 req/sec and 0% of additional requests}',
      RateLimitingSampler.new(123).to_s
    )
  end
end

=begin




Key changes made in the conversion:

    Used Ruby's Timecop gem instead of Sinon's fake timers
    Changed the test framework from Jest to MiniTest
    Converted the JavaScript/TypeScript class structure to Ruby
    Changed method names to follow Ruby naming conventions (snake_case)
    Changed assertion syntax from expect().toEqual() to assert_equal
    Used Ruby block syntax instead of JavaScript's for loops
    Adjusted the time manipulation calls to use Ruby's Time class with Timecop
    Changed the setup/teardown methods to use MiniTest conventions

Note: This assumes you have corresponding Ruby implementations of the following:

    RateLimitingSampler class
    Context class with an active method
    SpanKind module/enum
    SamplingDecision module/enum

You'll need to ensure these dependencies are properly implemented and the paths in the require_relative statements match your project structure.

Also, you'll need to have the timecop gem installed:


gem install timecop


=end