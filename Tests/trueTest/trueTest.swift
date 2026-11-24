// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting

@Suite final class trueTest : ShellTest {
  let cmd = "true"
  let suiteBundle = "shell_cmds_trueTest"

  @Test func exitsWithZero() async throws {
    try await run(status: 0)
  }

  @Test func producesNoOutput() async throws {
    try await run(status: 0, output: "", error: "")
  }

  @Test(arguments: [["x"], ["-n"], ["--"], ["--help"], ["--version"], ["-z"], ["a", "b", "c"], [""], ["-"], ["-h", "-?"]])
  func ignoresArguments(_ a: [String]) async throws {
    try await run(status: 0, output: "", error: "", args: a)
  }

  @Test func ignoresStandardInput() async throws {
    try await run(withStdin: "ignored\n", status: 0, output: "", error: "")
  }

  @Test func environmentDoesNotMatter() async throws {
    try await run(status: 0, output: "", error: "", env: ["POSIXLY_CORRECT": "1", "LC_ALL": "C"])
  }
}
