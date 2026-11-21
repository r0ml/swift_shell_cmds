
// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// None of these tests can change the host name: the only attempt to set it uses a name that is too long to be
/// accepted (which fails whether or not the tests run as the super-user).
@Suite("hostname tests") final class hostnameTest : ShellTest {
  let cmd = "hostname"
  let suiteBundle = "shell_cmds_hostnameTest"

  /// The name the system reports, which is what hostname must print.
  static let fullName : String = {
    var buf = [CChar](repeating: 0, count: 256)
    gethostname(&buf, buf.count)
    return String(cString: buf)
  }()

  static var shortName : String { String(fullName.prefix { $0 != "." }) }

  static var domainName : String {
    if let dot = fullName.firstIndex(of: ".") {
      return String(fullName[fullName.index(after: dot)...])
    }
    return fullName
  }

  @Test func printsTheFullName() async throws {
    try await run(output: Self.fullName + "\n")
  }

  @Test(arguments: [["-f"], ["-f", "-f"]])
  func dashFIsTheDefault(_ args: [String]) async throws {
    try await run(output: Self.fullName + "\n", args: args)
  }

  @Test(arguments: [["-s"], ["-s", "-f"], ["-f", "-s"], ["-fs"], ["-sf"], ["-s", "-s"]])
  func shortName(_ args: [String]) async throws {
    try await run(output: Self.shortName + "\n", args: args)
  }

  @Test(arguments: [["-d"], ["-d", "-f"], ["-f", "-d"], ["-fd"], ["-df"], ["-d", "-d"]])
  func domainName(_ args: [String]) async throws {
    try await run(output: Self.domainName + "\n", args: args)
  }

  @Test(arguments: [["-s", "-d"], ["-d", "-s"], ["-sd"], ["-ds"], ["a", "b"], ["-s", "a", "b"], ["-x"], ["-?"]])
  func usageErrors(_ args: [String]) async throws {
    try await run(status: 1, error: /usage: hostname/, args: args)
  }

  @Test func doubleDashEndsOptions() async throws {
    try await run(output: Self.shortName + "\n", args: "-s", "--")
  }

  @Test func settingATooLongNameFails() async throws {
    // longer than the largest name the kernel accepts, so it is refused whoever runs the test
    let tooLong = String(repeating: "a", count: 300)
    try await run(status: 1, error: /sethostname/, args: tooLong)
  }
}
