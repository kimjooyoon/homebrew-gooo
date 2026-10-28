class GoooServiceGrantMcp < Formula
  desc "Review grants and saved MCP tool changes with Gooo"
  homepage "https://github.com/kimjooyoon/gooo-go-ports"
  version "0.1.0-preview.17"
  license "BSD-3-Clause"

  livecheck do
    skip "Pinned preview bundle; update after exact-source release verification"
  end

  on_macos do
    depends_on arch: :arm64
    on_arm do
      url "https://github.com/kimjooyoon/gooo-go-ports/releases/download/v0.1.0-preview.17/gooo-service-grant-mcp-darwin-arm64.tar.gz"
      sha256 "599dddf83fbfc09a7767166245326d19aba41b2e1a101dc2bd86f2c387d4447e"
    end
  end

  on_linux do
    depends_on arch: :x86_64
    on_intel do
      url "https://github.com/kimjooyoon/gooo-go-ports/releases/download/v0.1.0-preview.17/gooo-service-grant-mcp-linux-amd64.tar.gz"
      sha256 "47d4e96170ae3b6e54eae4ff128f8589a59c59cf64681d8a94d3f3eaa53c51f0"
    end
  end

  def install
    libexec.install Dir["*"]
    # A prefix license prevents Homebrew moving licenses out of the bundle.
    cp libexec/"LICENSE-transport-BSD", prefix/"LICENSE-transport-BSD"
    bin.write_exec_script libexec/"gooo-service-grant-mcp"
  end

  test do
    require "English"
    require "digest"
    require "json"
    require "timeout"

    manifest = JSON.parse((libexec/"BUNDLE.json").read)
    assert_equal "gooo/service-grant-mcp-native-bundle/v4", manifest.fetch("schema")
    assert_equal "7d801a6e78680f868db4da85f0c5f646def40151", manifest.fetch("source_commit")
    members = manifest.fetch("members")
    assert_equal 67, members.length
    assert_equal (members.keys + ["BUNDLE.json"]).sort, libexec.children.map { |path| path.basename.to_s }.sort
    members.each do |name, expected|
      path = libexec/name
      assert_predicate path, :file?
      refute_predicate path, :symlink?
      assert_equal expected.fetch("bytes"), path.size
      assert_equal expected.fetch("mode"), path.stat.mode & 0777
      assert_equal expected.fetch("sha256"), Digest::SHA256.file(path).hexdigest
    end

    (testpath/"empty-bin").mkpath
    child_env = { "PATH" => (testpath/"empty-bin").to_s, "GOROOT" => nil, "GOTOOLCHAIN" => nil }
    flags = %w[--many-required --alias-origin-change --definition-snapshot]
    %w[2025-11-25 2026-07-28].product((0...8).to_a).each do |protocol, bits|
      args = flags.select.with_index { |_flag, index| bits[index] == 1 }
      IO.popen(child_env, [bin/"gooo-service-grant-mcp", *args], "r+") do |io|
        exchange = lambda do |id, method, params|
          io.puts JSON.generate(jsonrpc: "2.0", id: id, method: method, params: params)
          io.flush
          reply = Timeout.timeout(15) { JSON.parse(io.readline) }
          assert_equal id, reply["id"]
          refute reply.key?("error"), reply.inspect
          reply.fetch("result")
        end

        initialized = exchange.call(1, "initialize", {
          protocolVersion: protocol, capabilities: {},
          clientInfo: { name: "homebrew-test", version: "1" }
        })
        assert_equal "gooo-service-grant", initialized.dig("serverInfo", "name")
        assert_equal protocol, initialized.fetch("protocolVersion")
        io.puts JSON.generate(jsonrpc: "2.0", method: "notifications/initialized")
        io.flush
        tools = exchange.call(2, "tools/list", {}).fetch("tools").map { |tool| tool.fetch("name") }
        expected_tools = ["assess_service_grant"]
        expected_tools << "assess_service_grant_change" if args.include?("--many-required")
        expected_tools << "gooo_compare_alias_origin" if args.include?("--alias-origin-change")
        expected_tools << "gooo_compare_saved_tool_definitions" if args.include?("--definition-snapshot")
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
          name: "assess_service_grant", arguments: facts.merge("unexpected" => true)
        })
        assert_equal true, malformed["isError"]
        refute malformed.key?("structuredContent")

        typed_call = lambda do |id, name, arguments|
          response = exchange.call(id, "tools/call", { name: name, arguments: arguments })
          refute response["isError"], response.inspect
          report = response.fetch("structuredContent")
          assert_equal report, JSON.parse(response.fetch("content").fetch(0).fetch("text"))
          report
        end

        if args.include?("--many-required")
          required = [{ "type" => "mcp", "name" => "weather" }, { "type" => "mcp", "name" => "calculator" }]
          many_facts = { "before" => "*", "after" => "mcp://*", "required_requests" => required }
          many = typed_call.call(10, "assess_service_grant_change", many_facts)
          expected_many = {
            "status" => "ELIGIBLE", "reason" => "SUBSET_AND_ALL_REQUIRED_REQUESTS_PRESERVED",
            "invalid_field" => "", "invalid_index" => -1, "first_counterexample" => -1,
            "request_count" => 2, "checked_count" => 2, "all_preserved" => true,
            "supported_subset" => true, "subset_rule_id" => "OLD_GLOBAL",
            "counterexample_before_match" => false, "counterexample_after_match" => false
          }
          assert_equal expected_many, many.fetch("decision")
          narrowed = typed_call.call(11, "assess_service_grant_change", many_facts.merge("after" => "mcp://weather"))
          assert_equal expected_many.merge("status" => "REFUSED", "reason" => "REQUIRED_REQUEST_REMOVED",
                                           "first_counterexample" => 1, "all_preserved" => false,
                                           "counterexample_before_match" => true), narrowed.fetch("decision")
        end

        if args.include?("--alias-origin-change")
          alias_facts = {
            "target_alias" => "docs_search",
            "before"       => [{ "server" => "docs", "original_name" => "search", "exposed_name" => "docs_search" }],
            "after"        => [{ "server" => "issues", "original_name" => "query", "exposed_name" => "docs_search" }],
          }
          alias_report = typed_call.call(20, "gooo_compare_alias_origin", alias_facts)
          decision = alias_report.fetch("decision")
          assert_match(%r{^gooo/alias-origin/v1/sha256:[0-9a-f]{64}$}, decision.fetch("context_id"))
          assert_equal({ "context_id" => decision.fetch("context_id"), "state" => "ORIGIN_CHANGED",
                         "reason" => "DIFFERENT_DECLARED_ORIGIN", "before_index" => 0, "after_index" => 0,
                         "conflict_catalog" => "", "conflict_first_index" => -1, "conflict_second_index" => -1,
                         "execution_authorized" => false }, decision)
        end

        if args.include?("--definition-snapshot")
          snapshot = JSON.parse((libexec/"snapshot-example.json").read)
          same = typed_call.call(30, "gooo_compare_saved_tool_definitions", snapshot)
          assert_equal "OBSERVED_DEFINITION_SAME", same.dig("decision", "state")

          changed = JSON.parse(JSON.generate(snapshot))
          page = JSON.parse(changed.fetch("after").fetch("pages").fetch(0).fetch("response_json"))
          page.fetch("result").fetch("tools").fetch(0).fetch("outputSchema")["type"] = "number"
          changed.fetch("after").fetch("pages").fetch(0)["response_json"] = JSON.generate(page)
          changed_report = typed_call.call(31, "gooo_compare_saved_tool_definitions", changed)
          assert_equal "OBSERVED_DEFINITION_CHANGED", changed_report.dig("decision", "state")

          incomplete = JSON.parse(JSON.generate(snapshot))
          page = JSON.parse(incomplete.fetch("after").fetch("pages").fetch(0).fetch("response_json"))
          page["result"] = { "tools" => [], "nextCursor" => "not-retained" }
          incomplete.fetch("after").fetch("pages").fetch(0)["response_json"] = JSON.generate(page)
          unknown = typed_call.call(32, "gooo_compare_saved_tool_definitions", incomplete)
          assert_equal "UNASSESSED", unknown.dig("decision", "state")
          [same, changed_report, unknown].each do |report|
            assert_equal "NOT_ASSESSED", report.dig("decision", "origin_relation")
            assert_equal "NOT_ASSESSED", report.dig("decision", "authorization_relation")
            assert_equal false, report.dig("decision", "behavior_equivalence_proven")
            assert_equal false, report.dig("decision", "execution_authorized")
            assert_equal false, report.dig("decision", "live_effect_performed")
          end
        end
        io.close_write
      rescue
        begin
          Process.kill("TERM", io.pid)
        rescue Errno::ESRCH
          nil
        end
        raise
      end
      assert_predicate $CHILD_STATUS, :success?
    end
  end
end
