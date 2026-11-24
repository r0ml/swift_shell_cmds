// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A directory of its own for a test, with helpers for the lock files in it.
final class ShlockDirectory {
  let root: String

  init() {
    var template = Array("/tmp/shlocktestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  func path(_ name: String) -> String { root + "/" + name }

  func read(_ name: String) -> [UInt8]? { try? FilePath(path(name)).readAllBytes() }

  func text(_ name: String) -> String? { read(name).map { String(decoding: $0, as: UTF8.self) } }

  func write(_ name: String, _ bytes: [UInt8], mode: mode_t = 0o644) {
    let fd = open(path(name), O_CREAT | O_WRONLY | O_TRUNC, mode)
    _ = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
    close(fd)
    chmod(path(name), mode)
  }

  func exists(_ name: String) -> Bool {
    var st = stat()
    return lstat(path(name), &st) == 0
  }

  func linkCount(_ name: String) -> Int? {
    var st = stat()
    return stat(path(name), &st) == 0 ? Int(st.st_nlink) : nil
  }

  /// The names of what is in the directory.
  func names(_ sub: String = "") -> [String] {
    guard let d = opendir(sub.isEmpty ? root : path(sub)) else { return [] }
    defer { closedir(d) }
    var result = [String]()
    while let e = readdir(d) {
      let name = withUnsafePointer(to: &e.pointee.d_name) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
      if name != "." && name != ".." { result.append(name) }
    }
    return result.sorted()
  }

  func remove() {
    for name in names("sub") { unlink(path("sub/" + name)) }
    rmdir(path("sub"))
    for name in names() {
      chmod(path(name), 0o755)
      unlink(path(name))
      rmdir(path(name))
    }
    rmdir(root)
  }
}

/// The number of a process that has gone.
func deadPid() -> pid_t {
  var pid: pid_t = 0
  var argv: [UnsafeMutablePointer<CChar>?] = [strdup("true"), nil]
  defer { free(argv[0]) }
  posix_spawn(&pid, "/usr/bin/true", nil, nil, argv, environ)
  var status: Int32 = 0
  waitpid(pid, &status, 0)
  return pid
}

/// Serialized: `run` changes PATH for the whole process.
@Suite("shlock", .serialized) final class shlockTest : ShellTest {
  let cmd = "shlock"
  let suiteBundle = "shell_cmds_shlockTest"

  static let usageText = "shlock: USAGE: shlock [-du] [-p PID] -f file\n"

  /// A process that is there for as long as the test is.
  let live = getpid()
  let dead = deadPid()

  /// The lock file's age matters: a lock is only taken away if it is older than the attempt to take it.
  func age() async throws { try await Task.sleep(for: .milliseconds(1100)) }

  // MARK: usage

  @Test(arguments: [[], ["-f"], ["-p"], ["-p", "5"], ["-f", "lock", "-p", "0"], ["-f", "lock", "-p", "abc"], ["-f", "lock", "-p", "-3"],
                    ["-x"], ["-"], ["-f", "lock", "-z"], ["-d"], ["-u"], ["-p", "3", "-f"], ["-f", "lock", "-p"], ["--"],
                    ["-f", "lock", "-p", "-"]])
  func usageErrors(_ args: [String]) async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(status: 1, output: "", error: Self.usageText, args: args, cd: FilePath(d.root))
    #expect(d.names().isEmpty)
  }

  /// Operands that aren't options are ignored.
  @Test func operandsAreIgnored() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(output: "", error: "", args: "extra", "-f", "lock", "more", cd: FilePath(d.root))
  }

  // MARK: checking

  @Test func noLockIsAGoodLock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(output: "", error: "", args: "-f", "lock", cd: FilePath(d.root))
    #expect(d.names().isEmpty)
  }

  @Test func lockOfALiveProcess() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(live)\n".utf8))
    try await run(output: "", error: "", args: "-f", "lock", cd: FilePath(d.root))
    try await run(output: "", error: "", args: "-flock", cd: FilePath(d.root))
  }

  @Test(arguments: ["\(0)\n", "-5\n", "hello\n", "", "\n", " \n"])
  func lockWithoutAProcess(_ content: String) async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array(content.utf8))
    try await run(status: 1, output: "", error: "", args: "-f", "lock", cd: FilePath(d.root))
    #expect(d.text("lock") == content)
  }

  @Test func lockOfADeadProcess() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8))
    try await run(status: 1, output: "", error: "", args: "-f", "lock", cd: FilePath(d.root))
    // checking leaves it alone
    #expect(d.text("lock") == "\(dead)\n")
  }

  @Test func processNumberWithoutALineEnd() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)".utf8))
    try await run(status: 1, args: "-f", "lock", cd: FilePath(d.root))
  }

  @Test func binaryLocks() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", withUnsafeBytes(of: live) { Array($0) })
    try await run(output: "", error: "", args: "-u", "-f", "lock", cd: FilePath(d.root))
    d.write("lock", withUnsafeBytes(of: dead) { Array($0) })
    try await run(status: 1, output: "", error: "", args: "-u", "-f", "lock", cd: FilePath(d.root))
    // too short to hold a number
    d.write("lock", [0x61, 0x62])
    try await run(status: 1, output: "", error: "", args: "-u", "-f", "lock", cd: FilePath(d.root))
    // a text lock isn't one
    d.write("lock", Array("\(live)\n".utf8))
    try await run(status: 0, args: "-f", "lock", cd: FilePath(d.root))
  }

  @Test func lockThatIsADirectory() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    mkdir(d.path("lock"), 0o755)
    try await run(status: 1, output: "", error: "", args: "-f", "lock", cd: FilePath(d.root))
  }

  @Test func unreadableLockIsTakenToBeGood() async throws {
    if getuid() == 0 { return }
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8), mode: 0)
    try await run(status: 0, output: "", error: "shlock: open(lock): Permission denied\n", args: "-f", "lock", cd: FilePath(d.root))
  }

  // MARK: making a lock

  @Test func makesTheLock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(output: "", error: "", args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(live)\n")
    // and nothing else is left
    #expect(d.names() == ["lock"])
    #expect(d.linkCount("lock") == 1)
    #expect(d.exists("lock"))
  }

  @Test func processNumberGivenInTheSameArgument() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(args: "-p\(live)", "-flock", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(live)\n")
  }

  @Test func thePermissionsOfTheLock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    let old = umask(0o022)
    defer { umask(old) }
    try await run(args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    var st = stat()
    #expect(stat(d.path("lock"), &st) == 0)
    #expect(st.st_mode & 0o7777 == 0o644)
  }

  @Test func binaryLockHoldsTheProcessNumber() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(args: "-u", "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.read("lock") == withUnsafeBytes(of: live) { Array($0) })
  }

  @Test func theLockIsGoodForTheProcessItIsMadeFor() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    try await run(args: "-f", "lock", cd: FilePath(d.root))
  }

  @Test func validLockIsRespected() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(live)\n".utf8))
    try await run(status: 1, output: "", error: "", args: "-f", "lock", "-p", "1", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(live)\n")
    #expect(d.names() == ["lock"])
  }

  @Test func invalidLockIsReplaced() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8))
    try await age()
    try await run(output: "", error: "", args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(live)\n")
    #expect(d.names() == ["lock"])
  }

  @Test(arguments: ["hello\n", "", "0\n", "-5\n"])
  func lockWithNoProcessIsReplaced(_ content: String) async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array(content.utf8))
    try await age()
    try await run(args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(live)\n")
  }

  @Test func binaryInvalidLockIsReplaced() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", withUnsafeBytes(of: dead) { Array($0) })
    try await age()
    try await run(args: "-u", "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.read("lock") == withUnsafeBytes(of: live) { Array($0) })
  }

  /// A lock that was only just made is not taken from its owner, even if the process doesn't exist: the time of the
  /// lock must be earlier than that of the attempt.
  @Test func lockMadeAtTheSameTimeIsLeftAlone() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8))
    try await run(status: 1, args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(dead)\n")
  }

  @Test func lockWithAnotherLinkIsLeftAlone() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8))
    link(d.path("lock"), d.path("other"))
    try await age()
    try await run(status: 1, args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(dead)\n")
    #expect(d.names() == ["lock", "other"])
  }

  @Test func lockInADirectory() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    mkdir(d.path("sub"), 0o755)
    // the temporary file is made next to the lock, so that a link can be made
    try await run(args: "-f", "sub/lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("sub/lock") == "\(live)\n")
    #expect(d.names() == ["sub"])
    #expect(d.names("sub") == ["lock"])
  }

  @Test func lockInAMissingDirectory() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(status: 1, output: "",
                  args: "-f", "missing/lock", "-p", "\(live)", cd: FilePath(d.root)) { po in
      #expect(po.error.hasPrefix("shlock: open(missing/shlock"))
      #expect(po.error.hasSuffix("): No such file or directory\n"))
    }
  }

  @Test func leftoverTemporaryFileIsReplaced() async throws {
    // a name the temporary file may have is not known beforehand: any file of that kind is just not in the way
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("shlock1", Array("old".utf8))
    try await run(args: "-f", "lock", "-p", "\(live)", cd: FilePath(d.root))
    #expect(d.text("lock") == "\(live)\n")
  }

  // MARK: saying what is done

  /// The lines of what shlock says with -d, with the process number of the shlock itself taken out.
  func debugLines(_ po: DarwinProcess.Output) -> [String] {
    String(decoding: po.data, as: UTF8.self).split(separator: "\n").map {
      String($0).replacing(/shlock\d+/, with: "shlockPID")
    }
  }

  @Test func debuggingMakingALock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(error: "", args: "-d", "-f", "lock", "-p", "\(live)", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: trying lock <lock> for process \(self.live)",
                                      "shlock: temporary filename: shlockPID",
                                      "shlock: got lock <lock>"])
    }
  }

  @Test func debuggingACheck() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    try await run(error: "", args: "-d", "-f", "lock", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: checking extant lock <lock>"])
    }
    d.write("lock", Array("\(live)\n".utf8))
    try await run(error: "", args: "-d", "-f", "lock", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: checking extant lock <lock>", "shlock: process \(self.live) is alive"])
    }
    d.write("lock", Array("\(dead)\n".utf8))
    try await run(status: 1, error: "", args: "-d", "-f", "lock", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: checking extant lock <lock>", "shlock: process \(self.dead) is dead \(self.dead)"])
    }
    d.write("lock", Array("junk\n".utf8))
    try await run(status: 1, error: "", args: "-d", "-f", "lock", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: checking extant lock <lock>", "shlock: process 0 is invalid"])
    }
    d.write("lock", [])
    try await run(status: 1, error: "", args: "-d", "-f", "lock", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: checking extant lock <lock>", "shlock: lock file format error"])
    }
  }

  @Test func debuggingTakingOverAnInvalidLock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8))
    try await age()
    try await run(error: "", args: "-d", "-f", "lock", "-p", "\(live)", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: trying lock <lock> for process \(self.live)",
                                      "shlock: temporary filename: shlockPID",
                                      "shlock: lock <lock> already exists",
                                      "shlock: checking extant lock <lock>",
                                      "shlock: process \(self.dead) is dead \(self.dead)",
                                      "shlock: lock is invalid, removing",
                                      "shlock: got lock <lock>"])
    }
  }

  @Test func debuggingAValidLock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(live)\n".utf8))
    try await run(status: 1, error: "", args: "-d", "-f", "lock", "-p", "1", cd: FilePath(d.root)) { po in
      #expect(self.debugLines(po) == ["shlock: trying lock <lock> for process 1",
                                      "shlock: temporary filename: shlockPID",
                                      "shlock: lock <lock> already exists",
                                      "shlock: checking extant lock <lock>",
                                      "shlock: process \(self.live) is alive",
                                      "shlock: extant lock is valid"])
    }
  }

  @Test func debuggingAnEarlyLock() async throws {
    let d = ShlockDirectory()
    defer { d.remove() }
    d.write("lock", Array("\(dead)\n".utf8))
    try await run(status: 1, error: "", args: "-d", "-f", "lock", "-p", "\(live)", cd: FilePath(d.root)) { po in
      let lines = self.debugLines(po)
      #expect(lines.last?.hasPrefix("shlock: lock time changed ") == true)
    }
  }
}
