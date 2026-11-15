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
    let pwd = Environment["PWD"] ?? ""
    try await run(output: pwd+"\n", error: "", args: "-S", "echo ${PWD}")
  }

  @Test("simple -S")
  func simpleS() async throws {
    let home = Environment["HOME"] ?? ""
    let pwd = Environment["PWD"] ?? ""
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

  @Test func assignmentVisibleToUtility() async throws {
    try await run(output: "bar\n", args: "FOO=bar", "/bin/sh", "-c", "echo $FOO")
  }

  @Test func assignmentsOnlyPrintsEnvironment() async throws {
    try await run(output: "A=1\n", args: "-i", "A=1")
  }

  @Test func assignmentValueContainingEquals() async throws {
    try await run(output: "A=b=c\n", args: "-i", "A=b=c")
  }

  @Test func assignmentEmptyValue() async throws {
    try await run(output: "A=\n", args: "-i", "A=")
  }

  @Test func nulTerminator() async throws {
    try await run(output: "A=1\0", args: "-0", "-i", "A=1")
  }

  @Test func nulWithUtilityIsError() async throws {
    try await run(status: 125, args: "-0", "/bin/echo", "x")
  }

  @Test func clearEnvironmentForUtility() async throws {
    try await run(output: "1|unset\n", args: "-i", "FOO=1", "/bin/sh", "-c", "echo $FOO\\|${HOME-unset}",
                  env: ["HOME": "/nonexistent"])
  }

  @Test func unsetForUtility() async throws {
    try await run(output: "unset\n", args: "-u", "FOO", "/bin/sh", "-c", "echo ${FOO-unset}", env: ["FOO": "x"])
  }

  @Test func unsetOnlyAffectsNamedVariable() async throws {
    try await run(output: "y\n", args: "-u", "FOO", "/bin/sh", "-c", "echo $BAR", env: ["FOO": "x", "BAR": "y"])
  }

  @Test func exitStatusPropagates() async throws {
    try await run(status: 7, args: "/bin/sh", "-c", "exit 7")
  }

  @Test func commandNotFound() async throws {
    try await run(status: 127, args: "-i", "no_such_command_xyz")
  }

  @Test func commandNotFoundWithPath() async throws {
    try await run(status: 127, args: "-P", "/usr/bin:/bin", "no_such_command_xyz")
  }

  @Test func alternatePathSearch() async throws {
    try await run(output: "hi\n", args: "-i", "-P", "/usr/bin:/bin", "echo", "hi")
  }

  @Test func doubleDashEndsOptions() async throws {
    try await run(output: "hi\n", args: "--", "/bin/echo", "hi")
  }

  @Test func stdinPassedThrough() async throws {
    try await run(withStdin: "hello", output: "hello", args: "/bin/cat")
  }

  @Test func veryVerboseDoesNotHang() async throws {
    try await run(output: "hi\n", error: nil, args: "-v", "-v", "/bin/echo", "hi")
  }

  @Test func invalidOption() async throws {
    try await run(status: 1, args: "-x")
  }

  @Test func splitStringWithOptions() async throws {
    try await run(output: "1\n", args: "-S", "-i FOO=1 /bin/sh -c 'echo $FOO'")
  }

  @Test func splitStringQuotedLeadingSpace() async throws {
    try await run(output: "  x\n", args: "-S", "/bin/echo \"  x\"")
  }

  @Test func splitStringQuotesGroupArguments() async throws {
    try await run(output: "1\n", args: "-S", "/bin/sh -c 'echo $#' x \"a  b\"")
  }

  @Test func splitStringEmptyQuotedArgument() async throws {
    try await run(output: "2\n", args: "-S", "/bin/sh -c 'echo $#' x '' y")
  }

  @Test func splitStringBackslashC() async throws {
    try await run(output: "a\n", args: "-S", "/bin/echo a \\c b")
  }

  @Test func splitStringComment() async throws {
    try await run(output: "a\n", args: "-S", "/bin/echo a #comment")
  }

  @Test func splitStringVariableExpansion() async throws {
    try await run(output: "zzz\n", args: "-S", "/bin/echo ${FOO}", env: ["FOO": "zzz"])
  }

  @Test func splitStringUndefinedVariable() async throws {
    try await run(output: "[]\n", args: "-S", "/bin/echo [${NO_SUCH_VAR_XYZ}]")
  }

  @Test func splitStringBackslashUnderscoreInQuotesIsBlank() async throws {
    try await run(output: "1\n", args: "-S", "/bin/sh -c 'echo $#' x \"a\\_b\"")
  }

  @Test func splitStringBackslashUnderscoreSeparates() async throws {
    try await run(output: "x-y\n", args: "-S", "/bin/sh -c 'echo $0-$1' x\\_y")
  }

  @Test func splitStringUnterminatedQuote() async throws {
    try await run(status: 1, args: "-S", "/bin/echo 'abc")
  }

  @Test func splitStringBadBackslash() async throws {
    try await run(status: 1, args: "-S", "/bin/echo \\q")
  }

  @Test func splitStringBadVariableSyntax() async throws {
    try await run(status: 1, args: "-S", "/bin/echo $FOO")
  }
}
