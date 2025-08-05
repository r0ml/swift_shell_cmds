// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import ShellTesting

@Suite("which tests") struct whichTest : ShellTest {
  let cmd = "which"
  let suiteBundle = "shell_cmds_whichTest"

    @Test func man() async throws {
      try await run(output: "/bin/ls\n/usr/bin/which\n", args: "ls", "which")
    }

  @Test func man2() async throws {
    try await run(status: 1, output: "", args: "-s", "ls", "which", "clem")
  }
}

