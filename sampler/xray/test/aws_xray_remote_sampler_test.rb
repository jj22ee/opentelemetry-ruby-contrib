# frozen_string_literal: true

# Copyright OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

DATA_DIR_SAMPLING_RULES = File.join(__dir__, 'data/test-remote-sampler_sampling-rules-response-sample.json')
DATA_DIR_SAMPLING_TARGETS = File.join(__dir__, 'data/test-remote-sampler_sampling-targets-response-sample.json')
TEST_URL = 'localhost:2000'

describe OpenTelemetry::Sampler::XRay::AWSXRayRemoteSampler do
  it 'creates remote sampler with empty resource' do
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_RULES))
    stub_request(:post, "#{TEST_URL}/SamplingTargets")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_TARGETS))

    sampler = OpenTelemetry::Sampler::XRay::InternalAWSXRayRemoteSampler.new(resource: OpenTelemetry::SDK::Resources::Resource.create)

    assert !sampler.instance_variable_get(:@rule_poller).nil?
    assert_equal(sampler.instance_variable_get(:@rule_polling_interval_millis), 300 * 1000)
    assert !sampler.instance_variable_get(:@sampling_client).nil?
    assert !sampler.instance_variable_get(:@rule_cache).nil?
    assert_match(/[a-f0-9]{24}/, sampler.instance_variable_get(:@client_id))
  end

  it 'creates remote sampler with populated resource' do
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_RULES))
    stub_request(:post, "#{TEST_URL}/SamplingTargets")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_TARGETS))

    resource = OpenTelemetry::SDK::Resources::Resource.create(
      OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'test-service-name',
      OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'test-cloud-platform'
    )
    sampler = OpenTelemetry::Sampler::XRay::InternalAWSXRayRemoteSampler.new(resource: resource)

    assert !sampler.instance_variable_get(:@rule_poller).nil?
    assert_equal(sampler.instance_variable_get(:@rule_polling_interval_millis), 300 * 1000)
    assert !sampler.instance_variable_get(:@sampling_client).nil?
    assert !sampler.instance_variable_get(:@rule_cache).nil?
    assert_equal(sampler.instance_variable_get(:@rule_cache).instance_variable_get(:@sampler_resource), resource)
    assert_match(/[a-f0-9]{24}/, sampler.instance_variable_get(:@client_id))
  end

  it 'creates remote sampler with all fields populated' do
    stub_request(:post, 'abc.com/GetSamplingRules')
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_RULES))
    stub_request(:post, 'abc.com/SamplingTargets')
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_TARGETS))

    resource = OpenTelemetry::SDK::Resources::Resource.create(
      OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'test-service-name',
      OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'test-cloud-platform'
    )
    sampler = OpenTelemetry::Sampler::XRay::InternalAWSXRayRemoteSampler.new(
      resource: resource,
      endpoint: 'abc.com',
      polling_interval: 120
    )

    assert !sampler.instance_variable_get(:@rule_poller).nil?
    assert_equal(sampler.instance_variable_get(:@rule_polling_interval_millis), 120 * 1000)
    assert !sampler.instance_variable_get(:@sampling_client).nil?
    assert !sampler.instance_variable_get(:@rule_cache).nil?
    assert_equal(sampler.instance_variable_get(:@rule_cache).instance_variable_get(:@sampler_resource), resource)
    assert_equal(sampler.instance_variable_get(:@aws_proxy_endpoint), 'abc.com')
    assert_match(/[a-f0-9]{24}/, sampler.instance_variable_get(:@client_id))
  end

  it 'updates sampling rules and targets with pollers and should sample' do
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_RULES))
    stub_request(:post, "#{TEST_URL}/SamplingTargets")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_TARGETS))

    resource = OpenTelemetry::SDK::Resources::Resource.create(
      OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'test-service-name',
      OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'test-cloud-platform'
    )

    OpenTelemetry::Sampler::XRay::AWSXRayRemoteSampler.new(resource: resource)

    # TODO...
  end

  it 'generates valid client id' do
    client_id = OpenTelemetry::Sampler::XRay::InternalAWSXRayRemoteSampler.generate_client_id
    assert_match(/[0-9a-z]{24}/, client_id)
  end

  it 'converts to string' do
    stub_request(:post, "#{TEST_URL}/GetSamplingRules")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_RULES))
    stub_request(:post, "#{TEST_URL}/SamplingTargets")
      .to_return(status: 200, body: File.read(DATA_DIR_SAMPLING_TARGETS))

    sampler = OpenTelemetry::Sampler::XRay::InternalAWSXRayRemoteSampler.new(resource: OpenTelemetry::SDK::Resources::Resource.create)
    expected_string = 'InternalAWSXRayRemoteSampler{aws_proxy_endpoint=127.0.0.1:2000, rule_polling_interval_millis=300000}'
    assert_equal(sampler.description, expected_string)
  end

  def create_spans(sampled_array, thread_id, span_attributes, remote_sampler, number_of_spans)
    sampled = 0
    number_of_spans.times do
      sampled += 1 if remote_sampler.should_sample?(parent_context: nil, trace_id: '3759e988bd862e3fe1be46a994272793', name: 'name', kind: OpenTelemetry::Trace::SpanKind::SERVER, attributes: {}, links: []).instance_variable_get(:@decision)
    end
    sampled_array[thread_id] = sampled
  end

  # it 'test_multithreading_with_large_reservoir' do
  #   stub_request(:post, /.*/).to_return { |request| mock_requests_get(url: request.uri.to_s) }

  #   rs = OpenTelemetry::Sampler::XRay::AWSXRayRemoteSampler.new(
  #     resource: OpenTelemetry::SDK::Resources::Resource.create({
  #                                                                'service.name' => 'test-service-name',
  #                                                                'cloud.platform' => 'test-cloud-platform'
  #                                                              })
  #   )

  #   attributes = { 'abc' => '1234' }
  #   sleep(2.0)
  #   assert_equal OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE,
  #                rs.should_sample?(parent_context: nil, trace_id: '3759e988bd862e3fe1be46a994272793', name: 'name', kind: OpenTelemetry::Trace::SpanKind::SERVER, attributes: {}, links: []).instance_variable_get(:@decision)
  #   sleep(3.0)

  #   number_of_spans = 100
  #   thread_count = 1000
  #   sampled_array = Array.new(thread_count, 0)
  #   threads = []

  #   thread_count.times do |idx|
  #     threads << Thread.new do
  #       create_spans(sampled_array, idx, attributes, rs, number_of_spans)
  #     end
  #   end

  #   threads.each(&:join)
  #   sum_sampled = sampled_array.sum

  #   test_rule_applier = rs.root.root.rule_cache.rule_appliers[0]
  #   assert_equal 100_000, test_rule_applier.reservoir_sampler.reservoir.quota
  #   assert_equal 100_000, sum_sampled
  # end
end

#
#
#
#   it('testLargeReservoir', done => {
#     nock(TEST_URL).post('/GetSamplingRules').reply(200, require(DATA_DIR_SAMPLING_RULES));
#     nock(TEST_URL).post('/SamplingTargets').reply(200, require(DATA_DIR_SAMPLING_TARGETS));
#     const resource = new Resource({
#       [SEMRESATTRS_SERVICE_NAME]: 'test-service-name',
#       [SEMRESATTRS_CLOUD_PLATFORM]: 'test-cloud-platform',
#     });
#     const attributes = { abc: '1234' };
#
#     // Patch default target polling interval
#     const tmp = (_AwsXRayRemoteSampler.prototype as any).getDefaultTargetPollingInterval;
#     (_AwsXRayRemoteSampler.prototype as any).getDefaultTargetPollingInterval = () => {
#       return 0.2; // seconds
#     };
#     const sampler = new AwsXRayRemoteSampler({
#       resource: resource,
#     });
#
#     setTimeout(() => {
#       expect(((sampler as any)._root._root.ruleCache as any).ruleAppliers[0].samplingRule.RuleName).toEqual('test');
#       expect(sampler.shouldSample(context.active(), '1234', 'name', SpanKind.CLIENT, attributes, []).decision).toEqual(
#         SamplingDecision.NOT_RECORD
#       );
#
#       setTimeout(() => {
#         let sampled = 0;
#         for (let i = 0; i < 100000; i++) {
#           if (
#             sampler.shouldSample(context.active(), '1234', 'name', SpanKind.CLIENT, attributes, []).decision !==
#             SamplingDecision.NOT_RECORD
#           ) {
#             sampled++;
#           }
#         }
#
#         // restore function
#         (_AwsXRayRemoteSampler.prototype as any).getDefaultTargetPollingInterval = tmp;
#
#         expect((sampler as any)._root._root.ruleCache.ruleAppliers[0].reservoirSampler.quota).toEqual(100000);
#         expect(sampled).toEqual(100000);
#         done();
#       }, 2000);
#     }, 100);
#   });
#
#   it('testSomeReservoir', done => {
#     nock(TEST_URL).post('/GetSamplingRules').reply(200, require(DATA_DIR_SAMPLING_RULES));
#     nock(TEST_URL).post('/SamplingTargets').reply(200, require(DATA_DIR_SAMPLING_TARGETS));
#     const resource = new Resource({
#       [SEMRESATTRS_SERVICE_NAME]: 'test-service-name',
#       [SEMRESATTRS_CLOUD_PLATFORM]: 'test-cloud-platform',
#     });
#     const attributes = { abc: 'non-matching attribute value, use default rule' };
#
#     // Patch default target polling interval
#     const tmp = (_AwsXRayRemoteSampler.prototype as any).getDefaultTargetPollingInterval;
#     (_AwsXRayRemoteSampler.prototype as any).getDefaultTargetPollingInterval = () => {
#       return 2; // seconds
#     };
#     const sampler = new AwsXRayRemoteSampler({
#       resource: resource,
#     });
#
#     setTimeout(() => {
#       expect(((sampler as any)._root._root.ruleCache as any).ruleAppliers[0].samplingRule.RuleName).toEqual('test');
#       expect(sampler.shouldSample(context.active(), '1234', 'name', SpanKind.CLIENT, attributes, []).decision).toEqual(
#         SamplingDecision.NOT_RECORD
#       );
#
#       setTimeout(() => {
#         const clock = sinon.useFakeTimers(Date.now());
#         clock.tick(2000);
#         let sampled = 0;
#         for (let i = 0; i < 100000; i++) {
#           if (
#             sampler.shouldSample(context.active(), '1234', 'name', SpanKind.CLIENT, attributes, []).decision !==
#             SamplingDecision.NOT_RECORD
#           ) {
#             sampled++;
#           }
#         }
#         clock.restore();
#         // restore function
#         (_AwsXRayRemoteSampler.prototype as any).getDefaultTargetPollingInterval = tmp;
#         expect(sampled).toEqual(100);
#         done();
#       }, 2000);
#     }, 300);
#   });
#
#
#
#
#
