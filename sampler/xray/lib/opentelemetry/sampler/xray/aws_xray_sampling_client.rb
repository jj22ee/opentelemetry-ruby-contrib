# frozen_string_literal: true

# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'net/http'
require 'json'
require 'uri'

module OpenTelemetry
  module Sampler
    module XRay
      class AWSXRaySamplingClient
        def initialize(endpoint)
          @endpoint = endpoint
          @host, @port = parse_endpoint(@endpoint)

          @sampling_rules_url = URI::HTTP.build(host: @host, path: '/GetSamplingRules', port: @port)
          @sampling_targets_url = URI::HTTP.build(host: @host, path: '/SamplingTargets', port: @port)
          @request_headers = {'content-type': 'application/json'}
        end

        def fetch_sampling_rules()
          begin
            OpenTelemetry::Common::Utilities.untraced {
              return Net::HTTP.post(@sampling_rules_url, '{}', @request_headers)
            }
          rescue StandardError => e
            OpenTelemetry.logger.debug("Error occurred when fetching Sampling Rules: #{e}")
          end
          return nil
        end

        def fetch_sampling_targets(request_body)
          begin
            OpenTelemetry::Common::Utilities.untraced {
              return Net::HTTP.post(@sampling_targets_url, request_body.to_json, @request_headers)
            }
          rescue StandardError => e
            OpenTelemetry.logger.debug("Error occurred when fetching Sampling Targets: #{e}")
          end
          return nil
        end

        private

        def parse_endpoint(endpoint)
          host, port = endpoint.split(':')
          [host, port.to_i]
        rescue StandardError => e
          OpenTelemetry.logger.error("Invalid endpoint: #{endpoint}")
          raise e
        end
      end
    end
  end
end
