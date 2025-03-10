# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require_relative '../../lib/sampler/statistics'

class StatisticsTest < Minitest::Test
  def test_construct_statistics_and_get_statistics
    statistics = Statistics.new(12, 3456, 7)

    assert_equal 12, statistics.request_count
    assert_equal 3456, statistics.sample_count 
    assert_equal 7, statistics.borrow_count

    obtained_statistics = statistics.get_statistics
    assert_equal 12, obtained_statistics.request_count
    assert_equal 3456, obtained_statistics.sample_count
    assert_equal 7, obtained_statistics.borrow_count
  end
end




=begin

Key changes made in the conversion:

    Changed from TypeScript/Jest to Ruby/MiniTest syntax
    Used Ruby naming conventions (snake_case instead of PascalCase for methods)
    Changed expect().toEqual() assertions to MiniTest's assert_equal
    Changed class definition style to match Ruby conventions
    Used Ruby's require/require_relative for imports
    Followed Ruby's test class naming convention by suffixing with "Test"

Note that this assumes the existence of a corresponding Statistics class in lib/sampler/statistics.rb with the appropriate methods and attributes. The Ruby class would need to implement request_count, sample_count, borrow_count as either methods or attr_readers, and have a get_statistics method that returns a statistics object.

=end