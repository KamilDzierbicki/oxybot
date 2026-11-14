ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/tracing_test_helper"

# Nothing leaves the machine. The model host is answered by the same MockLlm Rack app development uses,
# so tests exercise the real RubyLLM requests, schemas and tool calls.
WebMock.disable_net_connect!

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    parallelize(workers: :number_of_processors)

    fixtures :all

    setup do
      stub_request(:any, /mock-llm\.test/).to_rack(MockLlm.new)
    end

    def llm_requests(model)
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
             .select { |request| request.uri.host == "mock-llm.test" && request.body.to_s.include?(%("model":"#{model}")) }
    end

    def embed_features
      Feature.find_each(&:embed)
    end
  end
end
