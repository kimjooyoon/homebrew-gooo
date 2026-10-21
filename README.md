# Gooo tools for Homebrew

A maintainer tap for tools built from [Gooo](https://github.com/kimjooyoon/meta-ontology-go),
an experimental programming language with source-bound execution and replay.
This tap distributes the existing native MCP server from
[Gooo Go Ports](https://github.com/kimjooyoon/gooo-go-ports).

## Install

```sh
brew install kimjooyoon/gooo/gooo-service-grant-mcp
```

Supported bundles: macOS arm64 and Linux x86_64. Homebrew verifies the fixed
preview.16 archive SHA-256. The formula keeps the original runtime bundle,
manifest and third-party notices together; it adds only an executable launcher.
Running this server needs no Go, Gooo compiler, Python or model API key.
This tap is maintained by the project and is separate from Homebrew/core.

## Connect a coding agent

Find the installed launcher:

```sh
printf '%s/bin/gooo-service-grant-mcp\n' "$(brew --prefix kimjooyoon/gooo/gooo-service-grant-mcp)"
```

Use that absolute path as the stdio command in your client's MCP configuration.
The [client setup and two-call task](https://github.com/kimjooyoon/gooo-go-ports/blob/fceb89f8b53eabd6687d16258d7cee89853c2cfe/docs/ai-agents.md#connect-the-service-grant-mcp-tool)
covers Codex, Claude Code and Cursor. Existing host permissions stay under the
user's control; installing this formula does not edit agent configuration.

The default tool, `assess_service_grant`, checks whether a narrower service
pattern preserves one required request. To expose the optional ordered-list
tool as well, pass `--many-required` to the same executable. Results retain the
supplied facts, typed decision and source/generation bindings. The server
performs no grant change, authenticates no supplied facts and calls no service.

```sh
brew test kimjooyoon/gooo/gooo-service-grant-mcp
```

The formula test opens actual MCP stdio sessions with Go absent from the child
PATH, exercises default/optional tool discovery, checks a complete seven-field
decision and rejects malformed arguments. It is a finite installation smoke
test; the [upstream release](https://github.com/kimjooyoon/gooo-go-ports/releases/tag/v0.1.0-preview.16)
has its own broader source and native validation.

For install/launcher problems, open an issue in this tap. For a policy example
or language question, use [Gooo Go Ports feedback](https://github.com/kimjooyoon/gooo-go-ports/issues/new?template=problem.yml)
or the [Gooo language repository](https://github.com/kimjooyoon/meta-ontology-go).
Include your platform, formula version, first failed command and diagnostic;
share public or synthetic inputs only.
