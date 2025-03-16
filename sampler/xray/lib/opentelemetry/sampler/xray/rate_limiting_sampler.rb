# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative './rate_limiter'

# Constants to match OpenTelemetry enums
# module SamplingDecision
#   RECORD_AND_SAMPLED = 'RECORD_AND_SAMPLED'
#   NOT_RECORD = 'NOT_RECORD'
# end

module OpenTelemetry
  module Sampler
    module XRay


class RateLimitingSampler
  def initialize(quota)
    @quota = quota
    @reservoir = RateLimiter.new(quota)
  end

  def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
    # puts "rateLimit shouldtry"
    tracestate = OpenTelemetry::Trace.current_span(parent_context).context.tracestate
    if @reservoir.take(1)
      puts "reservoir.take(1)"
      OpenTelemetry::SDK::Trace::Samplers::Result.new(
        decision:  OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE,
        tracestate: tracestate,
        attributes: attributes
      )
    else
      OpenTelemetry::SDK::Trace::Samplers::Result.new(
        decision:  OpenTelemetry::SDK::Trace::Samplers::Decision::DROP,
        tracestate: tracestate,
        attributes: attributes
      )
    end
  end

  def to_s
    "RateLimitingSampler{rate limiting sampling with sampling config of #{@quota} req/sec and 0% of additional requests}"
  end
end

    end
  end
end

=begin

Key changes made in the conversion:

    Changed TypeScript class syntax to Ruby class syntax
    Converted private variables using @ instance variables
    Removed type annotations since Ruby is dynamically typed
    Changed implements to just a regular class definition since Ruby doesn't have explicit interface implementations
    Converted the SamplingDecision enum to a Ruby module with constants
    Changed method naming to follow Ruby conventions (e.g., toString became to_s)
    Changed the object literal syntax to Ruby hash syntax
    Used Ruby's require_relative for importing the RateLimiter dependency

Note: This assumes there's a corresponding Ruby implementation of the RateLimiter class in a file named rate_limiter.rb in the same directory. Also, some of the OpenTelemetry-specific types (Context, Link, SpanKind, etc.) would need to be defined elsewhere in your Ruby application or provided by a Ruby OpenTelemetry SDK.

=end
