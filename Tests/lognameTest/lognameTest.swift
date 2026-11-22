// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

@Suite("logname tests") final class lognameTest : ShellTest {
  let cmd = "logname"
  let suiteBundle = "shell_cmds_lognameTest"

  static let usageText = "usage: logname\n"

  /// The login name of the session the tests run in, which logname inherits.
  static let loginName : String? = getlogin().map { String(cString: $0) }

  @Test func printsTheLoginName() async throws {
    guard let name = Self.loginName else {
      try await run(status: 1, output: "", error: /logname: .+/)
      return
    }
    try await run(output: name + "\n")
  }

  /// The environment can't be trusted, so LOGNAME and USER are ignored.
  @Test(arguments: [["LOGNAME": "nobody_zz"], ["USER": "nobody_zz"], ["LOGNAME": "a", "USER": "b"], ["LOGNAME": ""]])
  func ignoresTheEnvironment(_ env: [String: String]) async throws {
    guard let name = Self.loginName else { return }
    try await run(output: name + "\n", env: env)
  }

  @Test func writesOnlyTheNameAndANewline() async throws {
    guard let name = Self.loginName else { return }
    try await run(output: name + "\n", error: "")
  }

  @Test(arguments: [["-x"], ["x"], ["--"], ["-- ", "x"], ["-"], ["-h"], ["x", "y"], ["-?"], [""], ["-l"]])
  func anyArgumentIsAUsageError(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Self.usageText, args: args)
  }
}
