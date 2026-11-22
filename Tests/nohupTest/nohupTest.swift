// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A working directory and a home directory for a test, inside a directory of its own.
final class NohupDirectories {
  let root: String
  let work: String
  let home: String

  init() {
    var template = Array("/tmp/nohuptestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    work = root + "/work"
    home = root + "/home"
    mkdir(work, 0o755)
    mkdir(home, 0o755)
  }

  func exists(_ path: String) -> Bool { access(path, F_OK) == 0 }

  func contents(_ path: String) -> String? {
    guard let bytes = try? FilePath(path).readAllBytes() else { return nil }
    return String(decoding: bytes, as: UTF8.self)
  }

  func mode(_ path: String) -> mode_t? {
    var st = stat()
    return lstat(path, &st) == 0 ? st.st_mode & 0o7777 : nil
  }

  func write(_ path: String, _ text: String, mode: mode_t = 0o644) {
    let fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, mode)
    _ = text.withCString { Darwin.write(fd, $0, strlen($0)) }
    close(fd)
    chmod(path, mode)
  }

  /// Removes everything a test can have made here.
  func remove() {
    chmod(work, 0o755)
    for dir in [work, home] {
      unlink(dir + "/nohup.out")
      rmdir(dir + "/nohup.out")
      rmdir(dir)
    }
    rmdir(root)
  }
}

/// Serialized: `run` changes PATH for the whole process, and the tests that start nohup themselves rely on it.
@Suite("nohup tests", .serialized) final class nohupTest : ShellTest {
  let cmd = "nohup"
  let suiteBundle = "shell_cmds_nohupTest"

  static let usageText = "usage: nohup [--] utility [arguments]\n"

  /// The path of the nohup under test, found the way `run` finds it.
  func nohupExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  /// Runs nohup with a terminal as its standard output and standard error (what makes it write nohup.out).
  /// Returns the exit status.
  func runOnTerminal(_ args: [String], in d: NohupDirectories, home: String? = nil, noHome: Bool = false) throws -> Int32 {
    let path = try nohupExecutable()
    let master = posix_openpt(O_RDWR | O_NOCTTY)
    guard master >= 0, grantpt(master) == 0, unlockpt(master) == 0, let slaveName = ptsname(master) else {
      throw POSIXErrno(errno)
    }
    defer { close(master) }

    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addchdir_np(&actions, d.work)
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&actions, 1, slaveName, O_RDWR | O_NOCTTY, 0)
    posix_spawn_file_actions_addopen(&actions, 2, slaveName, O_RDWR | O_NOCTTY, 0)

    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // nothing else is passed on to the child (the other tests' pipes, for one)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))

    var environment = Environment.getenv()
    if noHome {
      environment["HOME"] = nil
    } else {
      environment["HOME"] = home ?? d.home
    }
    var envp: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
    defer { for p in envp + argv { free(p) } }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, envp)
    guard rc == 0 else { throw POSIXErrno(rc) }
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
  }

  // MARK: usage

  @Test(arguments: [[String](), ["--"]])
  func missingUtility(_ args: [String]) async throws {
    try await run(status: 127, output: "", error: Self.usageText, args: args)
  }

  @Test(arguments: ["-x", "-n", "-h", "-?", "-1"])
  func options(_ opt: String) async throws {
    try await run(status: 127, output: "", error: "nohup: illegal option -- \(opt.dropFirst())\n" + Self.usageText, args: opt, "echo", "hi")
  }

  // MARK: running the utility

  @Test func runsTheUtility() async throws {
    try await run(output: "a b c d\n", args: "echo", "a", "b", "c d")
  }

  @Test func doubleDashEndsOptions() async throws {
    try await run(output: "hi\n", args: "--", "echo", "hi")
  }

  @Test func doubleDashIsOnlyConsumedOnce() async throws {
    try await run(status: 127, error: "nohup: --: No such file or directory\n", args: "--", "--", "echo", "hi")
  }

  @Test func utilityNamesAreNotOptions() async throws {
    try await run(status: 127, error: "nohup: -: No such file or directory\n", args: "-", "echo")
  }

  /// The utility sees its name as it was given, and its own arguments (including ones that look like options).
  @Test func argumentsAreUnchanged() async throws {
    try await run(output: "a 2 b c\n", args: "sh", "-c", "echo \"$0 $# $@\"", "a", "b", "c")
    try await run(output: "-x -y\n", args: "echo", "-x", "-y")
  }

  @Test(arguments: [0, 1, 2, 7, 64, 255])
  func exitStatusIsTheUtilitys(_ code: Int) async throws {
    try await run(status: code, args: "sh", "-c", "exit \(code)")
  }

  @Test func utilityKilledBySignal() async throws {
    try await run(status: 128 + Int(SIGKILL), args: "sh", "-c", "kill -9 $$")
  }

  @Test(arguments: [("nosuchcmd_zz", 127, "No such file or directory"), ("/nonexistent/cmd", 127, "No such file or directory"),
                    ("/etc/passwd", 126, "Permission denied"), ("/tmp", 126, "Permission denied"),
                    ("", 127, "No such file or directory")])
  func utilityThatCannotBeRun(_ command: String, _ status: Int, _ why: String) async throws {
    try await run(status: status, error: "nohup: \(command): \(why)\n", args: command)
  }

  // MARK: hangups

  @Test func hangupIsIgnored() async throws {
    try await run(output: "survived\n", args: "sh", "-c", "kill -HUP $$; echo survived")
  }

  // MARK: standard output that is not a terminal

  @Test func nothingIsRedirectedWhenNotOnATerminal() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    try await run(output: "out\n", error: "err\n", args: "sh", "-c", "echo out; echo err >&2", cd: FilePath(d.work))
    #expect(!d.exists(d.work + "/nohup.out"))
  }

  // MARK: standard output that is a terminal

  @Test func outputGoesToNohupOut() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    let status = try runOnTerminal(["sh", "-c", "echo out; echo err >&2; exit 3"], in: d)
    #expect(status == 3)
    // standard error follows standard output
    #expect(d.contents(d.work + "/nohup.out") == "out\nerr\n")
    #expect(d.mode(d.work + "/nohup.out") == 0o600)
    #expect(!d.exists(d.home + "/nohup.out"))
  }

  @Test func outputIsAppended() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    d.write(d.work + "/nohup.out", "old\n", mode: 0o644)
    let status = try runOnTerminal(["echo", "new"], in: d)
    #expect(status == 0)
    #expect(d.contents(d.work + "/nohup.out") == "old\nnew\n")
    // an existing file keeps its mode
    #expect(d.mode(d.work + "/nohup.out") == 0o644)
  }

  @Test func theUtilitysTerminalIsNotATerminalAnymore() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    _ = try runOnTerminal(["sh", "-c", "test -t 1 && echo stdout-tty; test -t 2 && echo stderr-tty; echo done"], in: d)
    #expect(d.contents(d.work + "/nohup.out") == "done\n")
  }

  @Test func problemsRunningTheUtilityAreWrittenThere() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    let status = try runOnTerminal(["nosuchcmd_zz"], in: d)
    #expect(status == 127)
    #expect(d.contents(d.work + "/nohup.out") == "nohup: nosuchcmd_zz: No such file or directory\n")
  }

  @Test func hangupIsIgnoredOnATerminalToo() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    let status = try runOnTerminal(["sh", "-c", "kill -HUP $$; echo survived"], in: d)
    #expect(status == 0)
    #expect(d.contents(d.work + "/nohup.out") == "survived\n")
  }

  /// Not usable in the current directory: it is made in the home directory instead.
  @Test func fallsBackToTheHomeDirectory() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    mkdir(d.work + "/nohup.out", 0o755)
    let status = try runOnTerminal(["echo", "to-home"], in: d)
    #expect(status == 0)
    #expect(d.contents(d.home + "/nohup.out") == "to-home\n")
    #expect(d.mode(d.home + "/nohup.out") == 0o600)
  }

  @Test func homeDirectoryFileIsAppended() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    mkdir(d.work + "/nohup.out", 0o755)
    d.write(d.home + "/nohup.out", "homeold\n", mode: 0o644)
    _ = try runOnTerminal(["echo", "to-home"], in: d)
    #expect(d.contents(d.home + "/nohup.out") == "homeold\nto-home\n")
  }

  @Test func readOnlyWorkingDirectoryAlsoFallsBack() async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    chmod(d.work, 0o500)
    _ = try runOnTerminal(["echo", "x"], in: d)
    chmod(d.work, 0o755)
    #expect(d.contents(d.home + "/nohup.out") == "x\n")
    #expect(!d.exists(d.work + "/nohup.out"))
  }

  @Test(arguments: ["unset", "empty", "missing"])
  func noUsableFileGivesUp(_ kind: String) async throws {
    let d = NohupDirectories()
    defer { d.remove() }
    mkdir(d.work + "/nohup.out", 0o755)
    let status: Int32
    switch kind {
    case "unset": status = try runOnTerminal(["echo", "x"], in: d, noHome: true)
    case "empty": status = try runOnTerminal(["echo", "x"], in: d, home: "")
    default: status = try runOnTerminal(["echo", "x"], in: d, home: "/nonexistent")
    }
    #expect(status == 127)
    #expect(!d.exists(d.home + "/nohup.out"))
  }
}
