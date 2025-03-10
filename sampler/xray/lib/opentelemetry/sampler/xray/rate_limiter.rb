# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

# The RateLimiter keeps track of the current reservoir quota balance available (measured via available time)
# If enough time has elapsed, the RateLimiter will allow quota balance to be consumed/taken (decrease available time)
# A RateLimitingSampler uses this RateLimiter to determine if it should sample or not based on the quota balance available.
class RateLimiter
  def initialize(quota, max_balance_in_seconds = 1)
    @max_balance_millis = max_balance_in_seconds * 1000.0
    @quota = quota
    @wallet_floor_millis = Time.now.to_f * 1000
    # current "balance" would be `ceiling - floor`
  end

  def take(cost = 1)
    return false if @quota == 0

    quota_per_millis = @quota / 1000.0

    # assume divide by zero not possible
    cost_in_millis = cost / quota_per_millis

    wallet_ceiling_millis = Time.now.to_f * 1000
    current_balance_millis = wallet_ceiling_millis - @wallet_floor_millis
    current_balance_millis = [current_balance_millis, @max_balance_millis].min
    pending_remaining_balance_millis = current_balance_millis - cost_in_millis

    if pending_remaining_balance_millis >= 0
      @wallet_floor_millis = wallet_ceiling_millis - pending_remaining_balance_millis
      return true
    end

    # No changes to the wallet state
    false
  end
end


=begin


Key changes made in the conversion:

    Changed TypeScript class syntax to Ruby class syntax
    Removed type annotations as Ruby is dynamically typed
    Changed private instance variables to use Ruby's @ notation
    Changed Date.now() to Time.now.to_f * 1000 to get current time in milliseconds
    Changed Math.min() to Ruby's array method min using array syntax [a, b].min
    Changed method return syntax to use implicit returns (last expression in method)
    Changed constructor name from constructor to initialize
    Removed public and private keywords as they're not needed in this context in Ruby
    Changed boolean values to Ruby style (true and false)

The functionality remains the same as the TypeScript version, maintaining the rate limiting logic while adapting to Ruby's syntax and conventions.


=end