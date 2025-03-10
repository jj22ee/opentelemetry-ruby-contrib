# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative './rate_limiting_sampler'

# FallbackSampler samples 1 req/sec and additional 5% of requests using TraceIdRatioBasedSampler.
class FallbackSampler
  def initialize
    @fixed_rate_sampler = TraceIdRatioBasedSampler.new(0.05)
    @rate_limiting_sampler = RateLimitingSampler.new(1)
  end

  def should_sample(context:, trace_id:, span_name:, span_kind:, attributes:, links:)
    sampling_result = @rate_limiting_sampler.should_sample(
      context: context,
      trace_id: trace_id,
      span_name: span_name,
      span_kind: span_kind,
      attributes: attributes,
      links: links
    )

    return sampling_result if sampling_result.decision != SamplingDecision::NOT_RECORD

    @fixed_rate_sampler.should_sample(context: context, trace_id: trace_id)
  end

  def to_s
    'FallbackSampler{fallback sampling with sampling config of 1 req/sec and 5% of additional requests'
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