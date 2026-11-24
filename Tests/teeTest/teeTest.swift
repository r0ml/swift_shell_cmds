// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A directory of its own for a test, with helpers for the files in it.
final class TeeDirectory {
  let root: String

  init() {
    var template = Array("/tmp/teetestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  func path(_ name: String) -> String { root + "/" + name }

  func read(_ name: String) -> [UInt8]? { try? FilePath(path(name)).readAllBytes() }

  func text(_ name: String) -> String? { read(name).map { String(decoding: $0, as: UTF8.self) } }

  func write(_ name: String, _ text: String, mode: mode_t = 0o644) {
    let fd = open(path(name), O_CREAT | O_WRONLY | O_TRUNC, mode)
    _ = text.withCString { Darwin.write(fd, $0, strlen($0)) }
    close(fd)
    chmod(path(name), mode)
  }

  func mode(_ name: String) -> mode_t? {
    var st = stat()
    return stat(path(name), &st) == 0 ? st.st_mode & 0o7777 : nil
  }

  func remove() {
    if let d = opendir(root) {
      while let e = readdir(d) {
        let name = withUnsafePointer(to: &e.pointee.d_name) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
        if name != "." && name != ".." {
          chmod(path(name), 0o755)
          unlink(path(name))
          rmdir(path(name))
        }
      }
      closedir(d)
    }
    rmdir(root)
  }
}

/// Serialized: `run` changes PATH for the whole process.
@Suite("tee", .serialized) final class teeTest : ShellTest {
  let cmd = "tee"
  let suiteBundle = "shell_cmds_teeTest"

  /// The path of the tee under test, found the way `run` finds it.
  func teeExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  // MARK: usage

  @Test(arguments: ["-z", "-x", "-?", "-aq"])
  func unknownOption(_ opt: String) async throws {
    let bad = opt.dropFirst().last!
    try await run(withStdin: "", status: 1, output: "", error: "tee: illegal option -- \(bad)\nusage: tee [-ai] [file ...]\n", args: opt)
  }

  // MARK: copying

  @Test func toStandardOutputOnly() async throws {
    try await run(withStdin: "only stdout\n", output: "only stdout\n", error: "", args: [String]())
  }

  @Test func noInput() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "", output: "", error: "", args: "a", cd: FilePath(d.root))
    #expect(d.text("a") == "")
  }

  @Test func toFilesToo() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "hello\n", output: "hello\n", error: "", args: "a", "b", "c", cd: FilePath(d.root))
    #expect(d.text("a") == "hello\n")
    #expect(d.text("b") == "hello\n")
    #expect(d.text("c") == "hello\n")
  }

  @Test func filesAreReplaced() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    d.write("a", "PREVIOUS CONTENTS\n")
    try await run(withStdin: "new\n", output: "new\n", args: "a", cd: FilePath(d.root))
    #expect(d.text("a") == "new\n")
  }

  @Test(arguments: ["-a", "-ai", "-ia", "-i -a"])
  func filesAreAppendedTo(_ opts: String) async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    d.write("a", "PRE\n")
    try await run(withStdin: "more\n", output: "more\n", error: "", args: opts.split(separator: " ").map(String.init) + ["a"], cd: FilePath(d.root))
    #expect(d.text("a") == "PRE\nmore\n")
  }

  @Test func appendCreatesTheFile() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "x\n", output: "x\n", args: "-a", "new", cd: FilePath(d.root))
    #expect(d.text("new") == "x\n")
  }

  @Test func optionsAfterAFileAreFiles() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "x\n", output: "x\n", args: "a", "-a", cd: FilePath(d.root))
    #expect(d.text("a") == "x\n")
    #expect(d.text("-a") == "x\n")
  }

  @Test func doubleDashEndsOptions() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "x\n", output: "x\n", args: "--", "-a", cd: FilePath(d.root))
    #expect(d.text("-a") == "x\n")
  }

  @Test func theSameFileTwice() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "dup\n", output: "dup\n", args: "a", "a", cd: FilePath(d.root))
    // two descriptors, each writing at its own position: the second write is over the first
    #expect(d.text("a") == "dup\n")
  }

  @Test func thePermissionsOfNewFiles() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    let old = umask(0o022)
    defer { umask(old) }
    try await run(withStdin: "x", args: "a", cd: FilePath(d.root))
    #expect(d.mode("a") == 0o644)
    umask(0o077)
    try await run(withStdin: "x", args: "b", cd: FilePath(d.root))
    #expect(d.mode("b") == 0o600)
  }

  @Test func existingModesAreKept() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    d.write("a", "old", mode: 0o600)
    try await run(withStdin: "x", args: "a", cd: FilePath(d.root))
    #expect(d.mode("a") == 0o600)
  }

  @Test func devices() async throws {
    try await run(withStdin: "to null\n", output: "to null\n", error: "", args: "/dev/null")
    // the standard output is written to as a file too
    try await run(withStdin: "twice\n", output: "twice\ntwice\n", error: "", args: "/dev/stdout")
  }

  @Test func binaryDataIsUnchanged() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    let bytes = (0..<256).map { UInt8($0) } + [0, 0, 255, 10, 13]
    try await run(withStdin: bytes, output: bytes, error: "", args: "a", cd: FilePath(d.root))
    #expect(d.read("a") == bytes)
  }

  /// More than one buffer of it.
  @Test func largeInput() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    let bytes = (0..<200_000).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ $0 >> 8) }
    try await run(withStdin: bytes, output: bytes, error: "", args: "a", "b", cd: FilePath(d.root))
    #expect(d.read("a") == bytes)
    #expect(d.read("b") == bytes)
  }

  // MARK: files that cannot be written

  @Test(arguments: [("nodir/a", "No such file or directory"), ("sub", "Is a directory"), ("ro", "Permission denied"), ("", "No such file or directory")])
  func fileThatCannotBeOpened(_ name: String, _ why: String) async throws {
    if getuid() == 0 && name == "ro" { return }
    let d = TeeDirectory()
    defer { d.remove() }
    mkdir(d.path("sub"), 0o755)
    d.write("ro", "old", mode: 0o444)
    // the failure doesn't stop the copy, only changes the status
    try await run(withStdin: "data\n", status: 1, output: "data\n", error: "tee: \(name): \(why)\n", args: name, "good", cd: FilePath(d.root))
    #expect(d.text("good") == "data\n")
    #expect(d.text("ro") == "old")
  }

  @Test func everyFailureIsReported() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    try await run(withStdin: "data\n", status: 1, output: "data\n",
                  error: "tee: nodir/a: No such file or directory\ntee: nodir/b: No such file or directory\n", args: "nodir/a", "nodir/b", cd: FilePath(d.root))
  }

  // MARK: interrupts

  /// Starts tee with pipes for its input and output.
  func start(_ args: [String], in d: TeeDirectory) throws -> (pid: pid_t, input: Int32, output: Int32) {
    let path = try teeExecutable()
    var inPipe: [Int32] = [0, 0]
    var outPipe: [Int32] = [0, 0]
    guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else { throw POSIXErrno(errno) }
    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addchdir_np(&actions, d.root)
    posix_spawn_file_actions_adddup2(&actions, inPipe[0], 0)
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], 1)
    posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // nothing else is passed on to the child (the other tests' pipes, for one)
    // the signals have their default action, whatever the test runner has done with them
    var defaults = sigset_t()
    sigemptyset(&defaults)
    sigaddset(&defaults, SIGINT)
    sigaddset(&defaults, SIGPIPE)
    var noSignals = sigset_t()
    sigemptyset(&noSignals)
    posix_spawnattr_setsigdefault(&attr, &defaults)
    posix_spawnattr_setsigmask(&attr, &noSignals)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
    var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
    defer { for p in argv { free(p) } }
    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, environ)
    close(inPipe[0])
    close(outPipe[1])
    guard rc == 0 else { throw POSIXErrno(rc) }
    return (pid, inPipe[1], outPipe[0])
  }

  /// How it ended; if it does not, it is made to (status -1).
  func exitStatus(_ pid: pid_t) -> Int32 {
    var status: Int32 = 0
    for _ in 0..<100 {
      if waitpid(pid, &status, WNOHANG) == pid {
        return (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
      }
      usleep(50_000)
    }
    kill(pid, SIGKILL)
    waitpid(pid, &status, 0)
    return -1
  }

  @Test func interruptKillsIt() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    let (pid, input, output) = try start([], in: d)
    defer { close(input); close(output) }
    try await Task.sleep(for: .milliseconds(300))
    kill(pid, SIGINT)
    #expect(exitStatus(pid) == 128 + SIGINT)
  }

  @Test func interruptIsIgnoredWithI() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    let (pid, input, output) = try start(["-i", "a"], in: d)
    defer { close(output) }
    try await Task.sleep(for: .milliseconds(300))
    kill(pid, SIGINT)
    try await Task.sleep(for: .milliseconds(200))
    // still there, and still copying
    _ = "after\n".withCString { Darwin.write(input, $0, 6) }
    close(input)
    var buffer = [UInt8](repeating: 0, count: 64)
    let n = read(output, &buffer, buffer.count)
    #expect(String(decoding: buffer[0..<max(n, 0)], as: UTF8.self) == "after\n")
    #expect(exitStatus(pid) == 0)
    #expect(d.text("a") == "after\n")
  }

  @Test func closedOutputKillsIt() async throws {
    let d = TeeDirectory()
    defer { d.remove() }
    let (pid, input, output) = try start(["a"], in: d)
    close(output)
    try await Task.sleep(for: .milliseconds(300))
    _ = "x\n".withCString { Darwin.write(input, $0, 2) }
    close(input)
    // as with any program that writes to a pipe nobody reads: the files were written first or not at all, but it is
    // the signal that ends it
    #expect(exitStatus(pid) == 128 + SIGPIPE)
  }
}
