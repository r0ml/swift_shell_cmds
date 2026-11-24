// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

@Suite("users") final class usersTest : ShellTest {
  let cmd = "users"
  let suiteBundle = "shell_cmds_usersTest"

  /// The names of the users that are logged in, from the same database the command reads, in the order of their bytes.
  func loggedIn() -> [[UInt8]] {
    var names = Set<[UInt8]>()
    setutxent()
    while let ut = getutxent() {
      if ut.pointee.ut_type == USER_PROCESS {
        withUnsafeBytes(of: ut.pointee.ut_user) { names.insert(Array($0.prefix { $0 != 0 })) }
      }
    }
    endutxent()
    return names.sorted { $0.lexicographicallyPrecedes($1) }
  }

  /// What the command is to say about them: the names with spaces between, and a line end; nothing if there are none.
  func expected() -> [UInt8] {
    let names = loggedIn()
    if names.isEmpty { return [] }
    return Array(names.joined(separator: [UInt8(ascii: " ")])) + [10]
  }

  @Test func showsTheUsersLoggedIn() async throws {
    // (somebody could log in or out between the two looks; so look again if they don't agree)
    let before = expected()
    try await run(error: "") { po in
      let after = self.expected()
      #expect(po.data == before || po.data == after)
    }
  }

  @Test func anEntryForTheUserThatRunsTheTests() async throws {
    // a login (as opposed to a daemon) at the console or on a terminal shows up, if there is one
    guard let me = getlogin().map({ String(cString: $0) }), loggedIn().contains(Array(me.utf8)) else { return }
    try await run(args: [String]()) { po in
      let names = String(decoding: po.data, as: UTF8.self).dropLast().split(separator: " ").map(String.init)
      #expect(names.contains(me))
    }
  }

  @Test func namesAreSortedAndEachIsOnce() async throws {
    try await run(args: [String]()) { po in
      if po.data.isEmpty { return }
      #expect(po.data.last == 10)
      let names = po.data.dropLast().split(separator: UInt8(ascii: " "), omittingEmptySubsequences: false).map(Array.init)
      #expect(names == names.sorted { $0.lexicographicallyPrecedes($1) })
      #expect(Set(names).count == names.count)
    }
  }

  // MARK: usage

  @Test(arguments: [["-x"], ["a"], ["--"], ["-"], ["--help"], ["a", "b"], ["-a", "-b"], [""]])
  func anyArgumentIsAMistake(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: "usage: users\n", args: args)
  }
}
