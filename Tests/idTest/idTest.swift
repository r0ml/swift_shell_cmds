
// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Each test runs the system's own id (or groups, or whoami) with the same arguments and expects the
/// same output and exit status, so the expected results are always those of the machine and user running
/// the tests.  (The -A option, whose output depends on privileges and the audit session, is not covered.)
@Suite("id tests") final class idTest : ShellTest {
  let cmd = "id"
  let suiteBundle = "shell_cmds_idTest"

  /// What the system command prints and exits with.
  func system(_ tool: String, _ args: [String]) async throws -> DarwinProcess.Output {
    try await DarwinProcess().run("/usr/bin/" + tool, args: args)
  }

  static let users = ["", "root", "daemon", "nobody", "nosuchuser", "0", "1", "99999", "4294967294", "4294967295",
                      "4294967296", " 0", "0 ", "+0", "-1", "0x0", "010"]

  static let options = ["", "-G", "-Gn", "-g", "-gn", "-gr", "-gnr", "-u", "-un", "-ur", "-unr", "-P", "-p", "-F", "-a",
                        "-aG", "-nG", "-rg"]

  @Test(arguments: options, users)
  func matchesSystemId(_ option: String, _ user: String) async throws {
    var args: [String] = []
    if !option.isEmpty { args.append(option) }
    if !user.isEmpty { args.append(user) }
    let expected = try await system("id", args)
    if expected.code == 0 {
      try await run(output: expected.data, args: args)
    } else {
      try await run(status: Int(expected.code), output: expected.data, error: /./, args: args)
    }
  }

  @Test(arguments: [["-G", "-g"], ["-g", "-u"], ["-p", "-P"], ["-F", "-G"], ["-n"], ["-r"], ["-nr"], ["-x"], ["-M"], ["-c"],
                    ["root", "nobody"], ["-u", "root", "nobody"], ["-Gn", "root", "root"], ["--"], ["--", "root"], ["-G", "--", "root"],
                    ["-A", "root"], ["-un", "-gn"], ["-Fn"], ["-Pn"], ["-pr"]])
  func matchesSystemIdForOptionCombinations(_ args: [String]) async throws {
    let expected = try await system("id", args)
    if expected.code == 0 {
      try await run(output: expected.data, args: args)
    } else {
      try await run(status: Int(expected.code), output: expected.data, error: /usage: id|no such user|illegal option/, args: args)
    }
  }

  @Test func usageText() async throws {
    try await run(status: 1, error: /usage: id \[user\]\n       id -A\n       id -F \[user\]\n       id -G \[-n\] \[user\]\n\n       id -P \[user\]\n       id -g \[-nr\] \[user\]\n       id -p \[user\]\n       id -u \[-nr\] \[user\]\n/, args: "-x")
  }

  @Test func largeIdIsNotNegative() async throws {
    try await run(output: "4294967294\n", args: "-u", "nobody")
  }

  @Test func passwdLineShowsSignedIds() async throws {
    try await run(output: /^nobody:\*:-2:-2:/, args: "-P", "nobody")
  }

  @Test func groupNamesHaveNoStrayParentheses() async throws {
    try await run(output: /^[^()]+\n$/, args: "-Gn")
  }

  @Test func allGroupsOfAUserAreListed() async throws {
    // a user's group list can be longer than the number of groups a process may have
    let expected = try await system("id", ["-G", "root"])
    try await run(output: expected.data, args: "-G", "root")
  }
}

/// id run under the names groups and whoami (through links to the built id).
@Suite("groups and whoami tests") final class idPersonalityTest : ShellTest {
  let cmd = "id"
  let suiteBundle = "shell_cmds_idTest"

  /// A link called `name` that points at the id built next to the test bundle (which is how Xcode runs the tests).
  static func link(_ name: String) -> String {
    guard let bundle = Environment["XCTestBundlePath"] else {
      return name
    }
    let id = FilePath(bundle).removingLastComponent().appending("id")
    let dir = FilePath(Environment["TMPDIR"] ?? "/tmp").appending("id_links_\(getpid())")
    try? dir.createDirectory(FilePermissions(rawValue: 0o755))
    let l = dir.appending(name)
    try? l.createSymbolicLink(to: id)
    return l.string
  }

  static let groupsLink = link("groups")
  static let whoamiLink = link("whoami")

  @Test(arguments: ["", "root", "daemon", "nobody", "nosuchuser", "0", "99999"])
  func groupsMatchesSystemGroups(_ user: String) async throws {
    let args = user.isEmpty ? [] : [user]
    let expected = try await DarwinProcess().run("/usr/bin/groups", args: args)
    let po = try await DarwinProcess().run(Self.groupsLink, args: args)
    #expect(po.code == expected.code)
    #expect(po.data == expected.data)
  }

  @Test func whoamiMatchesSystemWhoami() async throws {
    let expected = try await DarwinProcess().run("/usr/bin/whoami", args: [String]())
    let po = try await DarwinProcess().run(Self.whoamiLink, args: [String]())
    #expect(po.code == expected.code)
    #expect(po.data == expected.data)
  }

  @Test(arguments: [["-x"], ["somebody"], ["-u"], ["--"]])
  func whoamiRejectsWhatTheSystemWhoamiRejects(_ args: [String]) async throws {
    let expected = try await DarwinProcess().run("/usr/bin/whoami", args: args)
    let po = try await DarwinProcess().run(Self.whoamiLink, args: args)
    #expect(po.code == expected.code)
    #expect(po.data == expected.data)
  }
}
