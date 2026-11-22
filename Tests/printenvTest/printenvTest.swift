// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Serialized: `run` changes PATH for the whole process, and the tests that start printenv themselves rely on it.
@Suite("printenv tests", .serialized) final class printenvTest : ShellTest {
  let cmd = "printenv"
  let suiteBundle = "shell_cmds_printenvTest"

  struct Result {
    var status: Int32
    var output: [UInt8]
    var error: [UInt8]
    var text: String { String(decoding: output, as: UTF8.self) }
  }

  /// The path of the printenv under test, found the way `run` finds it.
  func printenvExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  /// Runs printenv with exactly this environment (given as the raw entries, so that it can hold duplicates,
  /// entries with no equals sign, and bytes that aren't text) and returns what it wrote.
  func runWith(environment: [[UInt8]], args: [String] = []) throws -> Result {
    let path = try printenvExecutable()
    var out: [Int32] = [0, 0], err: [Int32] = [0, 0]
    pipe(&out)
    pipe(&err)

    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_adddup2(&actions, out[1], 1)
    posix_spawn_file_actions_adddup2(&actions, err[1], 2)
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))

    func cString(_ bytes: [UInt8]) -> UnsafeMutablePointer<CChar> {
      let p = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count + 1)
      for (i, b) in bytes.enumerated() { p[i] = CChar(bitPattern: b) }
      p[bytes.count] = 0
      return p
    }
    var argv: [UnsafeMutablePointer<CChar>?] = (["printenv"] + args).map { strdup($0) } + [nil]
    var envp: [UnsafeMutablePointer<CChar>?] = environment.map { cString($0) } + [nil]
    defer { for p in argv + envp { p?.deallocate() } }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, envp)
    close(out[1])
    close(err[1])
    guard rc == 0 else { throw POSIXErrno(rc) }

    func drain(_ fd: Int32) -> [UInt8] {
      var all = [UInt8]()
      var buffer = [UInt8](repeating: 0, count: 65536)
      while true {
        let n = read(fd, &buffer, buffer.count)
        if n <= 0 { break }
        all += buffer[0..<n]
      }
      close(fd)
      return all
    }
    // (what is written to standard error is small, so reading standard output first can't block it)
    let output = drain(out[0])
    let error = drain(err[0])
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return Result(status: (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f), output: output, error: error)
  }

  func entries(_ strings: String...) -> [[UInt8]] { strings.map { Array($0.utf8) } }

  // MARK: the whole environment

  @Test func printsEveryEntryInTheOrderTheyAreIn() throws {
    let r = try runWith(environment: entries("B=2", "A=1", "C=3"))
    #expect(r.status == 0)
    #expect(r.text == "B=2\nA=1\nC=3\n")
  }

  /// Not sorted, whatever the names.
  @Test func orderIsNotSorted() throws {
    let r = try runWith(environment: entries("z=1", "Z=2", "a=3", "_=4", "1=5"))
    #expect(r.text == "z=1\nZ=2\na=3\n_=4\n1=5\n")
  }

  @Test func emptyEnvironment() throws {
    let r = try runWith(environment: [])
    #expect(r.status == 0)
    #expect(r.text == "")
    #expect(r.error.isEmpty)
  }

  @Test func entriesAreWrittenAsTheyAre() throws {
    let r = try runWith(environment: entries("FOO=a=b", "=x", "=", "NOEQUALS", "EMPTY=", "SPACE=a b  c", "TAB=a\tb"))
    #expect(r.text == "FOO=a=b\n=x\n=\nNOEQUALS\nEMPTY=\nSPACE=a b  c\nTAB=a\tb\n")
  }

  @Test func duplicatesAreAllWritten() throws {
    let r = try runWith(environment: entries("FOO=bar", "FOO=baz", "FOO=bar"))
    #expect(r.text == "FOO=bar\nFOO=baz\nFOO=bar\n")
  }

  @Test func valuesWithNewlines() throws {
    let r = try runWith(environment: entries("FOO=multi\nline", "B=2"))
    #expect(r.text == "FOO=multi\nline\nB=2\n")
  }

  /// A value is bytes: what isn't valid UTF-8 is passed through unchanged.
  @Test func bytesThatAreNotText() throws {
    let r = try runWith(environment: [Array("FOO=".utf8) + [0xff, 0xfe], Array("B=2".utf8)])
    #expect(r.output == Array("FOO=".utf8) + [0xff, 0xfe, 0x0a] + Array("B=2\n".utf8))
  }

  @Test func multibyteValues() throws {
    let r = try runWith(environment: entries("FOO=é日本", "é=accent"))
    #expect(r.text == "FOO=é日本\né=accent\n")
  }

  @Test func veryLongValues() throws {
    let long = String(repeating: "x", count: 100000)
    let r = try runWith(environment: entries("LONG=" + long))
    #expect(r.text == "LONG=" + long + "\n")
  }

  /// The runtime's own additions to the environment (such as __CF_USER_TEXT_ENCODING) are not shown.
  @Test func nothingIsAddedToTheEnvironment() throws {
    let r = try runWith(environment: entries("FOO=bar"))
    #expect(r.text == "FOO=bar\n")
    let q = try runWith(environment: entries("FOO=bar"), args: ["__CF_USER_TEXT_ENCODING"])
    #expect(q.status == 1)
    #expect(q.output.isEmpty)
  }

  // MARK: one variable

  @Test(arguments: [("FOO", "bar\n", 0), ("A", "1\n", 0), ("z", "zz\n", 0), ("_", "u\n", 0), ("1", "one\n", 0), ("é", "accent\n", 0),
                    ("BAR", "", 1), ("foo", "", 1), ("FO", "", 1), ("FOOO", "", 1), ("", "", 1), ("FOO=bar", "", 1), ("=", "", 1),
                    ("NOEQUALS", "", 1), ("A=1", "", 1), ("FOO ", "", 1), (" FOO", "", 1)])
  func lookUpOneName(_ name: String, _ expected: String, _ status: Int32) throws {
    let r = try runWith(environment: entries("FOO=bar", "A=1", "NOEQUALS", "z=zz", "_=u", "1=one", "é=accent"), args: [name])
    #expect(r.status == status)
    #expect(r.text == expected)
    #expect(r.error.isEmpty)
  }

  @Test func theFirstEntryWithTheNameIsUsed() throws {
    let r = try runWith(environment: entries("FOO=first", "FOO=second"), args: ["FOO"])
    #expect(r.text == "first\n")
  }

  @Test(arguments: [("FOO=", "\n"), ("FOO=a=b", "a=b\n"), ("FOO=multi\nline", "multi\nline\n"), ("FOO=é日本", "é日本\n")])
  func values(_ entry: String, _ expected: String) throws {
    let r = try runWith(environment: entries(entry), args: ["FOO"])
    #expect(r.status == 0)
    #expect(r.text == expected)
  }

  @Test func valuesThatAreNotText() throws {
    let r = try runWith(environment: [Array("FOO=".utf8) + [0xff, 0xfe]], args: ["FOO"])
    #expect(r.output == [0xff, 0xfe, 0x0a])
  }

  @Test func aVeryLongValue() throws {
    let long = String(repeating: "x", count: 100000)
    let r = try runWith(environment: entries("FOO=" + long), args: ["FOO"])
    #expect(r.text == long + "\n")
  }

  /// Only the first name matters.
  @Test func extraNamesAreIgnored() throws {
    let r = try runWith(environment: entries("FOO=bar", "BAR=baz"), args: ["FOO", "BAR"])
    #expect(r.status == 0)
    #expect(r.text == "bar\n")
    let q = try runWith(environment: entries("FOO=bar"), args: ["BAR", "FOO", "BAZ"])
    #expect(q.status == 1)
    #expect(q.text == "")
  }

  @Test func doubleDashEndsTheOptions() throws {
    let env = entries("FOO=bar", "-x=opt", "--=dd")
    let name = try runWith(environment: env, args: ["--", "FOO"])
    let dashed = try runWith(environment: env, args: ["--", "-x"])
    let dashes = try runWith(environment: env, args: ["--", "--"])
    let all = try runWith(environment: env, args: ["--"])
    #expect(name.text == "bar\n")
    #expect(dashed.text == "opt\n")
    #expect(dashes.text == "dd\n")
    #expect(all.text == "FOO=bar\n-x=opt\n--=dd\n")
  }

  // MARK: options

  @Test(arguments: [["-x"], ["-h"], ["-n"], ["-0"], ["--foo"], ["-xyz"], ["-x", "FOO"]])
  func options(_ args: [String]) throws {
    let r = try runWith(environment: entries("FOO=bar"), args: args)
    #expect(r.status == 1)
    #expect(r.output.isEmpty)
    #expect(String(decoding: r.error, as: UTF8.self).hasSuffix("usage: printenv [name]\n"))
  }

  /// Once there is a name, what follows is not looked at.
  @Test(arguments: [["FOO", "--"], ["FOO", "-x"], ["FOO", "BAR"]])
  func whatFollowsTheNameIsIgnored(_ args: [String]) throws {
    let r = try runWith(environment: entries("FOO=bar", "-x=opt"), args: args)
    #expect(r.status == 0)
    #expect(r.text == "bar\n")
    #expect(r.error.isEmpty)
  }

  /// A lone dash is a name, not an option.
  @Test func loneDash() throws {
    let r = try runWith(environment: entries("FOO=bar", "-=dash"), args: ["-"])
    #expect(r.status == 0)
    #expect(r.text == "dash\n")
  }

  // MARK: through the test harness

  @Test func valueOfAVariableSetByTheTest() async throws {
    try await run(output: "hello\n", args: "PRINTENV_TEST_VALUE", env: ["PRINTENV_TEST_VALUE": "hello"])
  }

  @Test func missingVariableThroughTheHarness() async throws {
    try await run(status: 1, output: "", error: "", args: "PRINTENV_TEST_SURELY_UNSET")
  }

  @Test func variableAppearsInTheWholeListing() async throws {
    try await run(args: [String](), env: ["PRINTENV_TEST_VALUE": "listed"]) { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n")
      #expect(lines.contains("PRINTENV_TEST_VALUE=listed"))
    }
  }
}
