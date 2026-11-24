// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Serialized: `run` changes PATH for the whole process, and the timing tests want the machine to themselves.
@Suite("sleep behavior", .serialized) final class sleepBehaviorTest : ShellTest {
  let cmd = "sleep"
  let suiteBundle = "shell_cmds_sleepTest"

  static let usageText = """
    usage: sleep number[unit] [...]
    Unit can be 's' (seconds, the default), m (minutes), h (hours), or d (days).

    """

  /// The path of the sleep under test, found the way `run` finds it.
  func sleepExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  // MARK: usage

  @Test(arguments: [[String](), ["inf"], ["1e999"], ["2147483648"], ["2147483647", "1"], ["--"]])
  func usageOnly(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Self.usageText, args: args)
  }

  @Test(arguments: ["x", "1x", "0s0", "1d1d", "0.01e", "0.01s0.01s", "-", "nan", "0.001 ", "--"])
  func invalidInterval(_ arg: String) async throws {
    // the operand "--" is only ignored when it comes first
    let operands = arg == "--" ? ["0.001", "--"] : [arg]
    try await run(status: 1, output: "", error: "sleep: invalid time interval: \(operands.last!)\n" + Self.usageText, args: operands)
  }

  @Test func everyInvalidIntervalIsReported() async throws {
    try await run(status: 1, output: "", error: "sleep: invalid time interval: x\nsleep: invalid time interval: 3x\n" + Self.usageText, args: "x", "0.01", "3x")
  }

  @Test(arguments: ["-x", "-1", "-0", "-inf", "-n", "-s"])
  func options(_ opt: String) async throws {
    try await run(status: 1, output: "", error: .init("sleep: illegal option -- \(opt.dropFirst().first!)\n" + Self.usageText), args: opt, "1")
  }

  // MARK: sleeping

  /// How long a run of sleep takes.
  func duration(_ args: String...) async throws -> Duration {
    let start = ContinuousClock.now
    try await run(output: "", error: "", args: args)
    return ContinuousClock.now - start
  }

  @Test func nothingToWaitFor() async throws {
    for arg in ["0", "0.0", ".0", "-- 0", "1e-10", "0s", "0m", "0d", "0x0", "1e-9"] {
      let start = ContinuousClock.now
      try await run(output: "", error: "", args: arg.split(separator: " ").map(String.init))
      #expect(ContinuousClock.now - start < .milliseconds(900), "\(arg)")
    }
  }

  @Test func fractionOfASecond() async throws {
    let d = try await duration("0.4")
    #expect(d >= .milliseconds(400) && d < .milliseconds(1500))
  }

  @Test(arguments: [("0.4s", 0.4), ("0.01m", 0.6), ("0x1", 1.0), ("1e-1", 0.1), ("+0.3", 0.3), (".3", 0.3), ("  0.3", 0.3)])
  func forms(_ arg: String, _ seconds: Double) async throws {
    let start = ContinuousClock.now
    try await run(output: "", error: "", args: arg)
    let d = ContinuousClock.now - start
    #expect(d >= .seconds(seconds), "\(arg)")
    #expect(d < .seconds(seconds + 1), "\(arg)")
  }

  @Test(arguments: [("0.0001h", 0.36), ("0.00001d", 0.864)])
  func hoursAndDays(_ arg: String, _ seconds: Double) async throws {
    let d = try await duration(arg)
    #expect(d >= .seconds(seconds * 0.98) && d < .seconds(seconds + 1))
  }

  @Test func intervalsAreAdded() async throws {
    let d = try await duration("0.3", "0.3", "0.3s")
    #expect(d >= .milliseconds(890) && d < .milliseconds(2000))
  }

  @Test func doubleDashComesFirst() async throws {
    let d = try await duration("--", "0.4")
    #expect(d >= .milliseconds(400) && d < .milliseconds(1500))
  }

  /// What comes after the first operand is an operand, even if it looks like an option: this one takes a second off.
  @Test func negativeIntervalsAreAdded() async throws {
    let d = try await duration("1.4", "-1")
    #expect(d >= .milliseconds(400) && d < .milliseconds(1100))
  }

  // MARK: reports

  /// Starts sleep with a pipe for its error output; the caller sends the signal and reads what came out.
  func startSleeping(_ args: [String]) throws -> (pid: pid_t, errorFD: Int32) {
    let path = try sleepExecutable()
    var fds: [Int32] = [0, 0]
    guard pipe(&fds) == 0 else { throw POSIXErrno(errno) }
    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
    posix_spawn_file_actions_adddup2(&actions, fds[1], 2)
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // nothing else is passed on to the child (the other tests' pipes, for one)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))
    var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
    defer { for p in argv { free(p) } }
    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, environ)
    close(fds[1])
    guard rc == 0 else { close(fds[0]); throw POSIXErrno(rc) }
    return (pid, fds[0])
  }

  @Test func progressIsReported() async throws {
    let (pid, fd) = try startSleeping(["3"])
    defer { close(fd) }
    try await Task.sleep(for: .milliseconds(500))
    kill(pid, SIGINFO)
    try await Task.sleep(for: .milliseconds(300))
    kill(pid, SIGINFO)
    try await Task.sleep(for: .milliseconds(200))
    kill(pid, SIGKILL)
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    var buffer = [UInt8](repeating: 0, count: 1024)
    let n = read(fd, &buffer, buffer.count)
    let text = String(decoding: buffer[0..<max(n, 0)], as: UTF8.self)
    #expect(text == "sleep: about 2 second(s) left out of the original 3\nsleep: about 2 second(s) left out of the original 3\n")
  }

  @Test func theSleepContinuesAfterAReport() async throws {
    let (pid, fd) = try startSleeping(["1.2"])
    defer { close(fd) }
    let start = ContinuousClock.now
    try await Task.sleep(for: .milliseconds(300))
    kill(pid, SIGINFO)
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    #expect(status == 0)
    #expect(ContinuousClock.now - start >= .milliseconds(1150))
    var buffer = [UInt8](repeating: 0, count: 1024)
    let n = read(fd, &buffer, buffer.count)
    #expect(String(decoding: buffer[0..<max(n, 0)], as: UTF8.self) == "sleep: about 0 second(s) left out of the original 1\n")
  }
}
