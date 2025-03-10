# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'minitest/autorun'
require_relative '../../src/sampler/utils'

class TestSamplingUtils < Minitest::Test
  POSITIVE_TESTS = [
    ['*', ''],
    ['foo', 'foo'],
    ['foo*bar*?', 'foodbaris'],
    ['?o?', 'foo'],
    ['*oo', 'foo'],
    ['foo*', 'foo'],
    ['*o?', 'foo'],
    ['*', 'boo'],
    ['', ''],
    ['a', 'a'],
    ['*a', 'a'],
    ['*a', 'ba'],
    ['a*', 'a'],
    ['a*', 'ab'],
    ['a*a', 'aa'],
    ['a*a', 'aba'],
    ['a*a*', 'aaaaaaaaaaaaaaaaaaaaaaa'],
    ['a*b*a*b*a*b*a*b*a*', '**********************byiaahkjbjhbuykj**********************aa**********************b'],
    ['a*na*ha', 'anananahahanahanaha'],
    ['***a', 'a'],
    ['**a**', 'a'],
    ['a**b', 'ab'],
    ['*?', 'a'],
    ['*??', 'aa'],
    ['*?', 'a'],
    ['*?*a*', 'ba'],
    ['?at', 'bat'],
    ['?at', 'cat'],
    ['?o?se', 'horse'],
    ['?o?se', 'mouse'],
    ['*s', 'horses'],
    ['J*', 'Jeep'],
    ['J*', 'jeep'],
    ['*/foo', '/bar/foo'],
    ['ja*script', 'javascript'],
    ['*', nil],
    ['*', ''],
    ['*', 'HelloWorld'],
    ['HelloWorld', 'HelloWorld'],
    ['Hello*', 'HelloWorld'],
    ['*World', 'HelloWorld'],
    ['?ello*', 'HelloWorld'],
    ['Hell?W*d', 'HelloWorld'],
    ['*.World', 'Hello.World'],
    ['*.World', 'Bye.World']
  ]

  NEGATIVE_TESTS = [
    ['', 'whatever'],
    ['/', 'target'],
    ['/', '/target'],
    ['foo', 'bar'],
    ['f?o', 'boo'],
    ['f??', 'boo'],
    ['fo*', 'boo'],
    ['f?*', 'boo'],
    ['abcd', 'abc'],
    ['??', 'a'],
    ['??', 'a'],
    ['*?*a', 'a'],
    ['a*na*ha', 'anananahahanahana'],
    ['*s', 'horse']
  ]

  def test_wildcard_match_with_only_wildcard
    assert Utils.wildcard_match('*', nil)
  end

  def test_wildcard_match_with_undefined_pattern
    refute Utils.wildcard_match(nil, '')
  end

  def test_wildcard_match_with_empty_pattern_and_text
    assert Utils.wildcard_match('', '')
  end

  def test_wildcard_match_with_regex_success
    POSITIVE_TESTS.each do |test|
      assert Utils.wildcard_match(test[0], test[1])
    end
  end

  def test_wildcard_match_with_regex_failure
    NEGATIVE_TESTS.each do |test|
      refute Utils.wildcard_match(test[0], test[1])
    end
  end

  def test_attribute_match_with_undefined_attributes
    rule_attributes = { 'string' => 'string', 'string2' => 'string2' }
    refute Utils.attribute_match(nil, rule_attributes)
    refute Utils.attribute_match({}, rule_attributes)
    refute Utils.attribute_match({ 'string' => 'string' }, rule_attributes)
  end

  def test_attribute_match_with_undefined_rule_attributes
    attr = {
      'number' => 1,
      'string' => 'string',
      'undefined' => nil,
      'boolean' => true
    }
    assert Utils.attribute_match(attr, nil)
  end

  def test_attribute_match_successful_match
    attr = { 'language' => 'english' }
    rule_attribute = { 'language' => 'en*sh' }
    assert Utils.attribute_match(attr, rule_attribute)
  end

  def test_attribute_match_failed_match
    attr = { 'language' => 'french' }
    rule_attribute = { 'language' => 'en*sh' }
    refute Utils.attribute_match(attr, rule_attribute)
  end

  def test_attribute_match_extra_attributes_success
    attr = {
      'number' => 1,
      'string' => 'string',
      'undefined' => nil,
      'boolean' => true
    }
    rule_attribute = { 'string' => 'string' }
    assert Utils.attribute_match(attr, rule_attribute)
  end

  def test_attribute_match_extra_attributes_failure
    attr = {
      'number' => 1,
      'string' => 'string',
      'undefined' => nil,
      'boolean' => true
    }
    rule_attribute = { 'string' => 'string', 'number' => '1' }
    refute Utils.attribute_match(attr, rule_attribute)
  end
end



=begin




Key changes made in the conversion:

    Used Ruby's MiniTest framework instead of Jest
    Changed describe blocks to a single test class inheriting from Minitest::Test
    Renamed test methods to follow Ruby convention (snake_case)
    Changed expect().toEqual() to assert and refute
    Converted JavaScript objects to Ruby hashes
    Used string keys in hashes instead of symbols to match the JavaScript behavior
    Changed undefined to nil
    Moved the test arrays to constants
    Used require_relative for importing the Utils module

Note that this assumes the existence of a corresponding Ruby implementation of the Utils module with wildcard_match and attribute_match methods.

=end