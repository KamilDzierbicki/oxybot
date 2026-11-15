require "test_helper"
require Rails.root.join("lib/boot/env_file").to_s

# bin/dev and the eval, prompt and Langfuse tasks read .env with this; without it they would call the mock model
class EnvFileTest < ActiveSupport::TestCase
  test "values from the file fill only what the shell has not set, skipping comments and empty values" do
    Tempfile.create(".env") do |file|
      file.write("# a comment\nLITELLM_URL=http://localhost:4010/v1\nLANGFUSE_URL=http://file\nEMPTY=\nTOKEN=a=b\n")
      file.flush
      env = { "LANGFUSE_URL" => "http://shell" }

      EnvFile.load(file.path, env: env)

      assert_equal({ "LANGFUSE_URL" => "http://shell", "LITELLM_URL" => "http://localhost:4010/v1", "TOKEN" => "a=b" }, env,
                   "the shell wins, and a value may contain =")
    end
  end

  test "a missing file changes nothing" do
    env = {}
    EnvFile.load("/nonexistent/.env", env: env)
    assert_empty env
  end
end
