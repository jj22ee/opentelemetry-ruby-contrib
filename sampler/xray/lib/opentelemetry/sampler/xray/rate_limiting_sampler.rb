# frozen_string_literal: true

# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative './rate_limiter'

module OpenTelemetry
  module Sampler
    module XRay
      class RateLimitingSampler
        def initialize(quota)
          @quota = quota
          @reservoir = RateLimiter.new(quota)
        end

        def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
          tracestate = OpenTelemetry::Trace.current_span(parent_context).context.tracestate
          if @reservoir.take(1)
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
