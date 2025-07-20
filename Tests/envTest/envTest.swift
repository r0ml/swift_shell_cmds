// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import ShellTesting

@Suite final class envTest : ShellTest {
  let cmd = "env"
  let suiteBundle = "shell_cmds_envTest"

  @Test("simple test")
  func simple() async throws {
    try await run(error: "#env clearing environ\n", args: "-i", "-v" )
  }

  @Test("simplest -S")
  func simplestS() async throws {
    let pwd = ProcessInfo.processInfo.environment["PWD"] ?? ""
    try await run(output: pwd+"\n", error: "", args: "-S", "echo ${PWD}")
  }

  @Test("simple -S")
  func simpleS() async throws {
    let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
    let pwd = ProcessInfo.processInfo.environment["PWD"] ?? ""
    let error = """
#env executing:  sh
#env    arg[0]=  'sh'
#env    arg[1]=  '-c'
#env    arg[2]=  'cd ; echo \(pwd) ; pwd'

"""
    let output = """
\(pwd)
\(home)

"""
    try await run(output: output, error: error, args: "-v", "-S", "sh -c \"cd ; echo ${PWD} ; pwd\"")
  }
}
