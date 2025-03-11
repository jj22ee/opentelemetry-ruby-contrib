# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative './rate_limiting_sampler'

module OpenTelemetry
  module Sampler
    module XRay

# FallbackSampler samples 1 req/sec and additional 5% of requests using TraceIdRatioBasedSampler.
class FallbackSampler
  def initialize
    @fixed_rate_sampler = OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(0.05)
    @rate_limiting_sampler = RateLimitingSampler.new(1)
  end

  def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
    sampling_result = @rate_limiting_sampler.should_sample?(
      trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes
    )

    return sampling_result if sampling_result.instance_variable_get(:@decision) != OpenTelemetry::SDK::Trace::Samplers::Decision::DROP

    @fixed_rate_sampler.should_sample?(trace_id:trace_id, parent_context:parent_context, links:links, name:name, kind:kind, attributes:attributes)
  end

  def to_s
    'FallbackSampler{fallback sampling with sampling config of 1 req/sec and 5% of additional requests'
  end
end

    end
  end
end

=begin


Key changes made in the conversion:

    Changed the TypeScript class syntax to Ruby class syntax
    Converted private instance variables from TypeScript to Ruby instance variables (using @)
    Changed the method naming to follow Ruby conventions (camelCase to snake_case)
    Converted the TypeScript interface implementation to a Ruby class
    Changed the parameter syntax to use Ruby's keyword arguments
    Removed explicit type declarations since Ruby is dynamically typed
    Changed the import syntax to Ruby's require_relative
    Changed the string representation method from toString() to to_s

Note: This conversion assumes the existence of corresponding Ruby classes for TraceIdRatioBasedSampler, SamplingDecision, and other dependencies. You'll need to ensure these classes and their required functionality are implemented in Ru Ruby as well.

Also note that Ruby doesn't have built-in interface implementation like TypeScript does. The Sampler interface behavior would need to be enforced through proper testing or documentation in a Ruby implementation.

=end