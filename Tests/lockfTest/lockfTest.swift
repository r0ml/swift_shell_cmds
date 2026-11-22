// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A directory of its own for a test, so that the lock files don't get in each other's way.
final class LockDirectory {
  let path: String

  init() {
    var template = Array("/tmp/lockftestXXXXXX".utf8CString)
    path = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  var directory: FilePath { FilePath(path) }

  func exists(_ name: String) -> Bool { access(path + "/" + name, F_OK) == 0 }

  func write(_ name: String, _ text: String = "") {
    let fd = open(path + "/" + name, O_CREAT | O_WRONLY | O_TRUNC, 0o666)
    _ = text.withCString { Darwin.write(fd, $0, strlen($0)) }
    close(fd)
  }

  /// Leaves the directory (which can only contain the lock file and what the test wrote) as it found /tmp.
  func remove(_ names: String...) {
    for n in names { unlink(path + "/" + n) }
    rmdir(path)
  }

  /// Holds the lock on `name`, as another process that is running a command under lockf would.
  func hold(_ name: String) -> Holder { Holder(path + "/" + name) }
}

struct Holder {
  let fd: Int32

  init(_ path: String) {
    // not inherited by anything a test starts, which would keep the lock after release()
    fd = open(path, O_CREAT | O_RDWR | O_CLOEXEC, 0o666)
    flock(fd, LOCK_EX)
  }

  func release() { close(fd) }
}

@Suite("lockf tests") final class lockfTest : ShellTest {
  let cmd = "lockf"
  let suiteBundle = "shell_cmds_lockfTest"

  static let usageText = """
    usage: lockf [-knsw] [-t seconds] file command [arguments]
           lockf [-s] [-t seconds] fd

    """

  // MARK: usage

  @Test(arguments: [[], ["-k"], ["-s"], ["-n", "-w"], ["--"]])
  func missingOperands(_ args: [String]) async throws {
    try await run(status: 64, error: Self.usageText, args: args)
  }

  @Test(arguments: ["-x", "-1", "-p", "-?"])
  func unknownOptions(_ opt: String) async throws {
    try await run(status: 64, error: Regex<Substring>(verbatim: "illegal option -- \(opt.dropFirst())\n" + Self.usageText),
                  args: [opt, "f", "echo", "hi"])
  }

  @Test func timeoutNeedsAnArgument() async throws {
    try await run(status: 64, error: Regex<Substring>(verbatim: "option requires an argument -- t\n" + Self.usageText),
                  args: ["-t"])
  }

  @Test(arguments: ["abc", "", "-1", "1x", "0x1", "1.5", "--1", "1 2", "1e3"])
  func invalidTimeouts(_ t: String) async throws {
    try await run(status: 64, error: "lockf: invalid timeout \"\(t)\"\n", args: ["-t", t, "f", "echo", "hi"])
  }

  /// strtol takes decimal, leading white space and a plus sign.
  @Test(arguments: ["5", "010", " 5", "+5", "0"])
  func validTimeouts(_ t: String) async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "hi\n", args: ["-t", t, "f", "echo", "hi"], cd: d.directory)
  }

  // MARK: running the command

  @Test func runsTheCommandAndRemovesTheLockFile() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "hi\n", args: "f", "echo", "hi", cd: d.directory)
    #expect(!d.exists("f"))
  }

  @Test func keepingTheLockFile() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "hi\n", args: "-k", "f", "echo", "hi", cd: d.directory)
    #expect(d.exists("f"))
  }

  @Test func theFileIsLockedWhileTheCommandRuns() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "exists\n", args: "f", "sh", "-c", "test -e f && echo exists", cd: d.directory)
  }

  @Test(arguments: [["a", "b", "c d"], ["-n", "x"], ["--", "y"], ["-k"], ["-t", "1"], ["a\nb"], [""]])
  func argumentsReachTheCommandUnchanged(_ args: [String]) async throws {
    let d = LockDirectory()
    defer { d.remove("f", "o") }
    let script = "for a in \"$@\"; do printf '<%s>' \"$a\"; done"
    try await run(output: args.map { "<\($0)>" }.joined(), args: ["f", "sh", "-c", script, "sh"] + args, cd: d.directory)
  }

  @Test func theCommandIsFoundOnThePath() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "a b\n", args: "f", "echo", "a", "b", cd: d.directory)
    try await run(output: "yes\n", args: "f", "/bin/echo", "yes", cd: d.directory)
  }

  @Test func standardStreamsArePassedThrough() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(withStdin: "hello\n", output: "hello\n", args: "f", "cat", cd: d.directory)
    try await run(output: "out\n", error: "err\n", args: "f", "sh", "-c", "echo err >&2; echo out", cd: d.directory)
  }

  @Test(arguments: [0, 1, 2, 7, 64, 127, 255])
  func theCommandsExitStatusIsReturned(_ code: Int) async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: code, args: "f", "sh", "-c", "exit \(code)", cd: d.directory)
    #expect(!d.exists("f"))
  }

  @Test func statusWrapsAroundLikeAnyExitStatus() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 44, args: "f", "sh", "-c", "exit 300", cd: d.directory)
  }

  @Test func aCommandThatDiesOfASignalIsSoftwareFailure() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 70, args: "f", "sh", "-c", "kill -9 $$", cd: d.directory)
    try await run(status: 70, args: "f", "sh", "-c", "kill -TERM $$", cd: d.directory)
    #expect(!d.exists("f"))
  }

  @Test(arguments: [("nosuchcmd_zz", "No such file or directory"), ("/nonexistent/cmd", "No such file or directory"),
                    ("/etc/passwd", "Permission denied"), ("/tmp", "Permission denied"), ("", "No such file or directory")])
  func aCommandThatCannotBeRun(_ command: String, _ why: String) async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 1, error: "lockf: \(command): \(why)\n", args: "f", command, cd: d.directory)
    #expect(!d.exists("f"))
  }

  @Test func theLockFileIsKeptWhenTheCommandCannotBeRun() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 1, error: "lockf: nosuchcmd_zz: No such file or directory\n", args: "-k", "f", "nosuchcmd_zz",
                  cd: d.directory)
    #expect(d.exists("f"))
  }

  /// Options end at the file name: what follows is the command.
  @Test(arguments: ["--", "-k", "-s"])
  func optionsAfterTheFileAreTheCommand(_ word: String) async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 1, error: "lockf: \(word): No such file or directory\n", args: "f", word, "echo", "hi",
                  cd: d.directory)
  }

  @Test func doubleDashEndsTheOptions() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "hi\n", args: "--", "f", "echo", "hi", cd: d.directory)
    try await run(output: "hi\n", args: "-k", "--", "f", "echo", "hi", cd: d.directory)
    #expect(d.exists("f"))
  }

  @Test(arguments: ["-ks", "-sk", "-kn", "-nk", "-kw", "-ksw"])
  func combinedOptions(_ opts: String) async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    d.write("f")
    try await run(output: "hi\n", args: opts, "f", "echo", "hi", cd: d.directory)
    #expect(d.exists("f"))
  }

  // MARK: the lock file

  @Test func missingFileWithN() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 69, error: "lockf: f: No such file or directory\n", args: "-n", "f", "echo", "hi", cd: d.directory)
    try await run(status: 69, error: "lockf: f: No such file or directory\n", args: "-kn", "f", "echo", "hi", cd: d.directory)
    #expect(!d.exists("f"))
  }

  @Test func existingFileWithN() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    d.write("f")
    try await run(output: "hi\n", args: "-n", "f", "echo", "hi", cd: d.directory)
    // the file is removed all the same
    #expect(!d.exists("f"))
    d.write("f")
    try await run(output: "hi\n", args: "-n", "-k", "f", "echo", "hi", cd: d.directory)
    #expect(d.exists("f"))
  }

  @Test func existingFileIsLockedNotTruncated() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    d.write("f", "keep me")
    try await run(output: "keep me", args: "-k", "f", "cat", "f", cd: d.directory)
  }

  @Test(arguments: [[String](), ["-w"]])
  func writingOrReading(_ opts: [String]) async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(output: "hi\n", args: opts + ["-k", "f", "echo", "hi"], cd: d.directory)
    #expect(d.exists("f"))
  }

  @Test func cannotCreateTheFile() async throws {
    try await run(status: 73, error: "lockf: cannot open /nonexistent/f: No such file or directory\n",
                  args: "/nonexistent/f", "echo", "hi")
    try await run(status: 73, error: "lockf: cannot open : No such file or directory\n", args: "", "echo", "hi")
  }

  @Test func missingDirectoryWithN() async throws {
    try await run(status: 69, error: "lockf: /nonexistent/f: No such file or directory\n",
                  args: "-n", "/nonexistent/f", "echo", "hi")
  }

  // MARK: another holder

  @Test(arguments: [[String](), ["-k"], ["-w"], ["-n"], ["-kwn"]])
  func timeoutOfZeroFailsAtOnce(_ opts: [String]) async throws {
    let d = LockDirectory()
    let h = d.hold("f")
    defer { h.release(); d.remove("f") }
    try await run(status: 75, error: "lockf: f: already locked\n", args: opts + ["-t", "0", "f", "echo", "x"], cd: d.directory)
    try await run(status: 75, error: "", args: opts + ["-s", "-t", "0", "f", "echo", "x"], cd: d.directory)
  }

  @Test(arguments: [[String](), ["-k"]])
  func timeoutExpires(_ opts: [String]) async throws {
    let d = LockDirectory()
    let h = d.hold("f")
    defer { h.release(); d.remove("f") }
    let start = ContinuousClock.now
    try await run(status: 75, output: "", error: "lockf: f: already locked\n", args: opts + ["-t", "1", "f", "echo", "x"],
                  cd: d.directory)
    #expect(ContinuousClock.now - start >= .milliseconds(900))
    #expect(ContinuousClock.now - start < .seconds(10))
  }

  @Test func silentTimeout() async throws {
    let d = LockDirectory()
    let h = d.hold("f")
    defer { h.release(); d.remove("f") }
    try await run(status: 75, output: "", error: "", args: "-s", "-t", "1", "f", "echo", "x", cd: d.directory)
  }

  /// The lock file is not removed by the process that gave up.
  @Test func aTimedOutLockfLeavesTheHoldersFile() async throws {
    let d = LockDirectory()
    let h = d.hold("f")
    defer { h.release(); d.remove("f") }
    try await run(status: 75, error: "lockf: f: already locked\n", args: "-t", "0", "f", "echo", "x", cd: d.directory)
    #expect(d.exists("f"))
  }

  /// lockf waits for the lock, and runs the command once the holder lets go.
  @Test(arguments: [["-t", "10"], ["-k", "-t", "10"], ["-k"], []])
  func waitsForTheLock(_ opts: [String]) async throws {
    let d = LockDirectory()
    let h = d.hold("f")
    defer { d.remove("f", "out") }
    let process = DarwinProcess()
    _ = try await process.launch(try await lockfExecutable(), args: opts + ["f", "sh", "-c", "echo got > out"], cd: d.directory)
    try await Task.sleep(for: .milliseconds(600))
    // it is still waiting: nothing has been run
    #expect(!d.exists("out"))
    h.release()
    let result = try await process.value()
    #expect(result.code == 0)
    #expect(result.error == "")
    #expect(try FilePath(d.path + "/out").readAllBytes() == Array("got\n".utf8))
  }

  // MARK: while the command runs

  /// The command can see that the lock is held.
  @Test func theLockIsHeldWhileTheCommandRuns() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(status: 75, error: "lockf: f: already locked\n",
                  args: "f", "sh", "-c", "lockf -t 0 f echo inner", cd: d.directory)
    #expect(!d.exists("f"))
  }

  @Test func theLockIsReleasedAfterTheCommand() async throws {
    let d = LockDirectory()
    defer { d.remove("f") }
    try await run(args: "-k", "f", "true", cd: d.directory)
    let h = d.hold("f")
    h.release()
    try await run(output: "again\n", args: "-k", "-t", "0", "f", "echo", "again", cd: d.directory)
  }

  // MARK: a file descriptor

  @Test(arguments: ["x", "3x", "", "1.5", "--", "0x3", "3 3"])
  func descriptorMustBeANumber(_ arg: String) async throws {
    try await run(status: 64, error: "Expected fd, got '\(arg)'\n" + Self.usageText, args: arg == "--" ? ["--", arg] : [arg])
  }

  @Test(arguments: ["99", " 99", "099", "+99"])
  func descriptorThatIsNotOpen(_ arg: String) async throws {
    try await run(status: 73, error: "lockf: cannot lock fd 99: Bad file descriptor\n", args: arg)
    try await run(status: 73, error: "lockf: cannot lock fd 99: Bad file descriptor\n", args: "-s", arg)
    try await run(status: 73, error: "lockf: cannot lock fd 99: Bad file descriptor\n", args: "-t", "1", arg)
  }

  /// The lock belongs to the open file, so it outlasts lockf: here the shell keeps descriptor 3 open.
  @Test func lockingADescriptor() async throws {
    let d = LockDirectory()
    defer { d.remove("f", "o") }
    let script = "exec 3>f; lockf 3 && echo locked; lockf -t 0 3 && echo again; exec 4<f; lockf -t 0 4; echo \"rc=$?\""
    try await run(output: "locked\nagain\nrc=75\n", error: "lockf: 4: already locked\n", args: "o", "sh", "-c", script,
                  cd: d.directory)
  }

  @Test func lockingADescriptorSilently() async throws {
    let d = LockDirectory()
    defer { d.remove("f", "o") }
    let script = "exec 3>f 4<f; lockf 3; lockf -s -t 0 4; echo \"rc=$?\""
    try await run(output: "rc=75\n", error: "", args: "o", "sh", "-c", script, cd: d.directory)
  }

  @Test func descriptorTimeout() async throws {
    let d = LockDirectory()
    defer { d.remove("f", "o") }
    let script = "exec 3>f 4<f; lockf 3; lockf -t x 4; echo \"rc=$?\""
    try await run(output: "rc=64\n", error: "lockf: invalid timeout \"x\"\n", args: "o", "sh", "-c", script, cd: d.directory)
  }

  // MARK: signals

  /// SIGTERM gives up the lock file (removing it unless -k) and then dies of the signal, leaving the command alone.
  @Test(arguments: [false, true])
  func terminated(_ keeping: Bool) async throws {
    let d = LockDirectory()
    defer { d.remove("f", "pid") }
    let lockfPath = try await lockfExecutable()
    let process = DarwinProcess()
    let pid = try await process.launch(lockfPath, args: (keeping ? ["-k"] : []) + ["f", "sh", "-c", "echo $$ > pid; sleep 10"],
                                       cd: d.directory)
    // wait for the command to have started
    var childPid: pid_t = 0
    for _ in 0..<100 {
      try await Task.sleep(for: .milliseconds(50))
      if d.exists("pid"), let text = try? FilePath(d.path + "/pid").readAllBytes(), let p = pid_t(String(decoding: text, as: UTF8.self).dropLast()) {
        childPid = p
        break
      }
    }
    #expect(childPid > 0)
    kill(pid, SIGTERM)
    try await Task.sleep(for: .milliseconds(300))
    #expect(d.exists("f") == keeping)
    // the command was not told; it is stopped here because it holds the pipes that lockf's output comes through
    #expect(kill(childPid, 0) == 0)
    kill(childPid, SIGKILL)
    let result = try await process.value()
    #expect(result.code == 128 + SIGTERM)
  }

  /// SIGINT and SIGQUIT are the command's business: lockf lets it run to the end.
  @Test(arguments: [SIGINT, SIGQUIT])
  func interruptsAreIgnored(_ sig: Int32) async throws {
    let d = LockDirectory()
    defer { d.remove("f", "ready") }
    let lockfPath = try await lockfExecutable()
    let process = DarwinProcess()
    let pid = try await process.launch(lockfPath, args: "f", "sh", "-c", "touch ready; sleep 1; exit 3", cd: d.directory)
    for _ in 0..<100 where !d.exists("ready") {
      try await Task.sleep(for: .milliseconds(50))
    }
    kill(pid, sig)
    let result = try await process.value()
    #expect(result.code == 3)
  }

  /// The path of the lockf under test, found the way `run` finds it.
  func lockfExecutable() async throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }
}
