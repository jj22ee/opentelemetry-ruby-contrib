# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'net/http'
require 'json'
require 'uri'

class AwsXraySamplingClient
  def initialize(endpoint, sampler_diag)
    @get_sampling_rules_endpoint = "#{endpoint}/GetSamplingRules"
    @sampling_targets_endpoint = "#{endpoint}/SamplingTargets"
    @sampler_diag = sampler_diag
  end

  def fetch_sampling_targets(request_body, &callback)
    make_request(
      @sampling_targets_endpoint,
      callback,
      -> (msg) { @sampler_diag.debug(msg) },
      request_body.to_json
    )
  end

  def fetch_sampling_rules(&callback)
    make_request(
      @get_sampling_rules_endpoint,
      callback,
      -> (msg) { @sampler_diag.error(msg) }
    )
  end

  private

  def make_request(url, callback, logger, request_body_json = nil)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri)

    if request_body_json
      request['Content-Type'] = 'application/json'
      request['Content-Length'] = request_body_json.bytesize.to_s
      request.body = request_body_json
    end

    # Note: Ruby doesn't have a direct equivalent to suppressTracing
    # You would need to implement similar functionality based on your tracing setup

    begin
      response = http.request(request)
      
      if response.code.to_i == 200 && !response.body.empty?
        begin
          response_object = JSON.parse(response.body)
          callback.call(response_object) if callback
        rescue JSON::ParserError => e
          logger.call("Error occurred when parsing responseData from #{url}")
        end
      else
        @sampler_diag.debug("#{url} Response Code is: #{response.code}")
        @sampler_diag.debug("#{url} responseData is: #{response.body}")
      end
    rescue StandardError => e
      logger.call("Error occurred when making an HTTP POST to #{url}: #{e}")
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