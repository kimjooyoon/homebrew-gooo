class GoooServiceGrantMcp < Formula
  desc "Inspect service-grant changes with Gooo over MCP stdio"
  homepage "https://github.com/kimjooyoon/gooo-go-ports"
  version "0.1.0-preview.16"
  license "BSD-3-Clause"

  on_macos do
    depends_on arch: :arm64
    url "https://github.com/kimjooyoon/gooo-go-ports/releases/download/v0.1.0-preview.16/gooo-service-grant-mcp-darwin-arm64.tar.gz"
    sha256 "a9f90f21fd10db3c6bfa0fae1372681131a4e84934acb4bb335cc26022fc47d8"
  end

  on_linux do
    depends_on arch: :x86_64
    url "https://github.com/kimjooyoon/gooo-go-ports/releases/download/v0.1.0-preview.16/gooo-service-grant-mcp-linux-amd64.tar.gz"
    sha256 "0ae9bc25eef2ad73535642a66b8b7602e9f64a148b3e60696e36048a3b4a0524"
  end

  livecheck do
    skip "Pinned preview bundle; update after exact-source release verification"
  end

  def install
    libexec.install Dir["*"]
    bin.write_exec_script libexec/"gooo-service-grant-mcp"
  end

  test do
    require "English"
    require "json"
    require "timeout"

    (testpath/"empty-bin").mkpath
    child_env = { "PATH" => (testpath/"empty-bin").to_s, "GOROOT" => nil, "GOTOOLCHAIN" => nil }
    [[], ["--many-required"]].each do |args|
      IO.popen(child_env, [bin/"gooo-service-grant-mcp", *args], "r+") do |io|
        begin
          exchange = lambda do |id, method, params|
            io.puts JSON.generate(jsonrpc: "2.0", id: id, method: method, params: params)
            io.flush
            reply = Timeout.timeout(15) { JSON.parse(io.readline) }
            assert_equal id, reply["id"]
            refute reply.key?("error"), reply.inspect
            reply.fetch("result")
          end

          initialized = exchange.call(1, "initialize", {
            protocolVersion: "2025-06-18", capabilities: {},
            clientInfo: { name: "homebrew-test", version: "1" },
          })
          assert_equal "gooo-service-grant", initialized.dig("serverInfo", "name")
          io.puts JSON.generate(jsonrpc: "2.0", method: "notifications/initialized")
          io.flush
          tools = exchange.call(2, "tools/list", {}).fetch("tools").map { |tool| tool.fetch("name") }
          expected_tools = ["assess_service_grant"]
          expected_tools << "assess_service_grant_change" unless args.empty?
          assert_equal expected_tools.sort, tools.sort

          facts = { "before" => "*", "after" => "mcp://*", "required_type" => "mcp", "required_name" => "weather" }
          result = exchange.call(3, "tools/call", { name: "assess_service_grant", arguments: facts })
          refute result["isError"]
          proof = result.fetch("structuredContent")
          assert_equal facts, proof.fetch("facts")
          assert_equal({ "status" => "ELIGIBLE", "reason" => "SUBSET_AND_REQUIRED_REQUEST_PRESERVED",
                         "invalid_field" => "", "required_observed" => true, "required_before_match" => true,
                         "required_after_match" => true, "subset_rule_id" => "OLD_GLOBAL" }, proof.fetch("decision"))
          assert_equal proof, JSON.parse(result.fetch("content").fetch(0).fetch("text"))
          assert_equal "205896a413e5dea92366309c35ae85e542d055f6", proof.dig("bindings", "compiler_source_sha")
          assert_match(/^sha256:[0-9a-f]{64}$/, proof.dig("bindings", "generation_sha256"))

          malformed = exchange.call(4, "tools/call", {
            name: "assess_service_grant", arguments: facts.merge("unexpected" => true),
          })
          assert_equal true, malformed["isError"]
          refute malformed.key?("structuredContent")
          io.close_write
        rescue StandardError
          begin
            Process.kill("TERM", io.pid)
          rescue Errno::ESRCH
            nil
          end
          raise
        end
      end
      assert_predicate $CHILD_STATUS, :success?
    end
  end
end
