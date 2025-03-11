
# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Sampler
    module XRay

class Statistics
  attr_accessor :request_count, :sample_count, :borrow_count

  def initialize(request_count: 0, sample_count: 0, borrow_count: 0)
    @request_count = request_count
    @sample_count = sample_count
    @borrow_count = borrow_count
  end

  def get_statistics
    {
      request_count: @request_count,
      sample_count: @sample_count,
      borrow_count: @borrow_count
    }
  end

  def reset_statistics
    @request_count = 0
    @sample_count = 0
    @borrow_count = 0
  end
end

    end
  end
end

=begin    

Key changes made in the conversion:

    Changed the TypeScript interface implementation to a plain Ruby class
    Converted camelCase to snake_case to follow Ruby conventions
    Replaced public properties with Ruby's attr_accessor
    Changed constructor parameters to use Ruby's keyword arguments
    Changed instance variables to use Ruby's @ notation
    Removed type annotations as Ruby is dynamically typed
    Changed method return type declarations to just method names
    Changed the hash syntax to use Ruby symbols
    Removed the void return type as it's not needed in Ruby

The functionality remains the same, but the code now follows Ruby conventions and syntax.


=end