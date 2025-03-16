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



=begin

Key differences and notes about the conversion:

    Ruby uses snake_case instead of camelCase for method and variable names

    Type annotations are removed since Ruby is dynamically typed

    The HTTP request handling is different:
        Ruby uses Net::HTTP instead of Node's http module
        The request/response handling is more synchronous in Ruby
        Error handling uses Ruby's exception handling patterns

    Callback handling is different:
        Ruby uses blocks (similar to callbacks) but they're passed using &block syntax
        The callback execution is more straightforward in Ruby

    The context/tracing suppression:
        The TypeScript code's context.with(suppressTracing...) doesn't have a direct equivalent
        You would need to implement this based on your specific tracing setup in Ruby

    Class structure:
        Ruby instance variables are prefixed with @
        Ruby doesn't need explicit private/public declarations (though they're available)
        Constructor is defined using initialize instead of constructor

This conversion assumes the existence of a DiagLogger equivalent in your Ruby codebase with debug and error methods. You might need to adjust the logging implementation based on your specific needs.



=end