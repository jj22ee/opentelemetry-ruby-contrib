# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require 'timecop'
require_relative '../../src/sampler/rate_limiter'

class RateLimiterTest < Minitest::Test
  def setup
    # Freeze time at the current moment
    @current_time = Time.now
    Timecop.freeze(@current_time)
  end

  def teardown
    # Return to normal time
    Timecop.return
  end

  def test_take
    limiter = RateLimiter.new(30, 1)

    # First batch - should get no tokens immediately
    spent = 0
    100.times do
      spent += 1 if limiter.take(1)
    end
    assert_equal 0, spent

    # Second batch - should get half the rate after 0.5 seconds
    Timecop.travel(@current_time + 0.5)
    spent = 0
    100.times do
      spent += 1 if limiter.take(1)
    end
    assert_equal 15, spent

    # Third batch - should get full rate after 1 second
    Timecop.travel(@current_time + 1000)
    spent = 0
    100.times do
      spent += 1 if limiter.take(1)
    end
    assert_equal 30, spent
  end
end



=begin

Key differences and notes:

    Instead of Sinon's fake timers, we use the timecop gem which is commonly used for time manipulation in Ruby tests.

    The class structure follows Ruby/MiniTest conventions:
        Test class inherits from Minitest::Test
        setup and teardown methods instead of beforeEach and afterEach
        Test method names start with test_

    The file naming convention in Ruby would typically be rate_limiter_test.rb (snake_case)

    Assertions use MiniTest's assertion syntax (assert_equal instead of expect().toEqual())

    Ruby's block syntax (do...end or {}) is used instead of JavaScript's arrow functions

    The path to the actual implementation file uses Ruby's convention (require_relative '../../src/sampler/rate_limiter')

Note that this assumes you have a corresponding Ruby implementation of the RateLimiter class in the referenced path. You'll also need to have the timecop gem installed, which you can do with:


gem install timecop



The Ruby implementation should maintain the same behavior as the TypeScript version, with the rate limiter allowing a specified number of tokens to be consumed over a given time period.

=end