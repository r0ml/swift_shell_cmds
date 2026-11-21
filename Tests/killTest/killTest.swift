// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Signals are only ever sent to processes that these tests start themselves, or to a pid that can't exist.
@Suite("kill tests") final class killTest : ShellTest {
  let cmd = "kill"
  let suiteBundle = "shell_cmds_killTest"

  /// A pid that is larger than any the system hands out.
  static let noSuchPid = "99999999"

  static let names = ["HUP", "INT", "QUIT", "ILL", "TRAP", "ABRT", "EMT", "FPE", "KILL", "BUS", "SEGV", "SYS", "PIPE",
                      "ALRM", "TERM", "URG", "STOP", "TSTP", "CONT", "CHLD", "TTIN", "TTOU", "IO", "XCPU", "XFSZ",
                      "VTALRM", "PROF", "WINCH", "INFO", "USR1", "USR2"]

  static let listing = """
    HUP INT QUIT ILL TRAP ABRT EMT FPE KILL BUS SEGV SYS PIPE ALRM TERM URG
    STOP TSTP CONT CHLD TTIN TTOU IO XCPU XFSZ VTALRM PROF WINCH INFO USR1 USR2

    """

  static let usageText = """
    usage: kill [-s signal_name] pid ...
           kill -l [exit_status]
           kill -signal_name pid ...
           kill -signal_number pid ...

    """

  /// Starts a sleeping child process that has the default disposition for every signal.
  static func spawnSleeper() -> pid_t {
    var pid: pid_t = 0
    var argv: [UnsafeMutablePointer<CChar>?] = [strdup("sleep"), strdup("30"), nil]
    defer { for a in argv { free(a) } }
    // The test runner may ignore or block signals, and the child would inherit that: reset all of them.
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    var all = sigset_t()
    sigfillset(&all)
    var none = sigset_t()
    sigemptyset(&none)
    posix_spawnattr_setsigdefault(&attr, &all)
    posix_spawnattr_setsigmask(&attr, &none)
    // Don't pass on any file descriptors: tests run in parallel, and a long-lived child that held the end of
    // another test's pipe would keep that test waiting for end-of-file.
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_CLOEXEC_DEFAULT))
    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    for fd in 0...2 {
      posix_spawn_file_actions_addopen(&actions, Int32(fd), "/dev/null", fd == 0 ? O_RDONLY : O_WRONLY, 0)
    }
    posix_spawnp(&pid, "sleep", &actions, &attr, argv, environ)
    return pid
  }

  /// Waits for `pid` and reports how it ended: the signal that killed it, or nil if it exited normally.
  static func terminationSignal(of pid: pid_t) -> Int32? {
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return (status & 0x7f) != 0 ? status & 0x7f : nil
  }

  // MARK: listing signals

  @Test func listsEverySignalName() async throws {
    try await run(output: Self.listing, args: ["-l"])
  }

  @Test(arguments: Array(Self.names.enumerated()))
  func namesTheSignalForANumber(_ entry: (offset: Int, element: String)) async throws {
    try await run(output: entry.element + "\n", args: ["-l", String(entry.offset + 1)])
  }

  /// An exit status above 128 means "killed by signal (status - 128)".
  @Test(arguments: [(129, "HUP"), (130, "INT"), (137, "KILL"), (143, "TERM"), (159, "USR2")])
  func namesTheSignalForAnExitStatus(_ n: Int, _ name: String) async throws {
    try await run(output: name + "\n", args: ["-l", String(n)])
  }

  @Test(arguments: ["0", "32", "127", "128", "160", "255", "99999999", "00", "99999999999999999999"])
  func unknownSignalNumbersListTheSignals(_ n: String) async throws {
    try await run(status: 2, error: "kill: unknown signal \(n); valid signals:\n" + Self.listing, args: ["-l", n])
  }

  @Test(arguments: ["1x", "9 ", "1e3", "0x9", "1.5", "7z"])
  func malformedSignalNumbers(_ n: String) async throws {
    try await run(status: 2, error: "kill: illegal signal number: \(n)\n", args: ["-l", n])
  }

  @Test(arguments: ["abc", "HUP", "-1", "", "+1", " 1"])
  func listArgumentThatIsNotANumberIsAUsageError(_ n: String) async throws {
    try await run(status: 2, error: Self.usageText, args: ["-l", n])
  }

  @Test func listTakesAtMostOneOperand() async throws {
    try await run(status: 2, error: Self.usageText, args: ["-l", "1", "2"])
  }

  // MARK: usage

  @Test func noArgumentsIsAUsageError() async throws {
    try await run(status: 2, error: Self.usageText)
  }

  @Test(arguments: [["--"], ["-9"], ["-HUP"], ["-s", "HUP"], ["-s", "KILL", "--"], ["-s", "0"]])
  func aSignalWithoutAPidIsAUsageError(_ args: [String]) async throws {
    try await run(status: 2, error: Self.usageText, args: args)
  }

  @Test func usageGoesToStandardErrorOnly() async throws {
    try await run(status: 2, output: "", error: Self.usageText)
  }

  @Test func dashSNeedsAnArgument() async throws {
    try await run(status: 2, error: /kill: option requires an argument -- s\nusage: kill/, args: ["-s"])
  }

  // MARK: choosing the signal

  @Test(arguments: ["-s HUP", "-s hup", "-s SIGHUP", "-s sighup", "-s SigHup", "-HUP", "-hup", "-SIGHUP", "-1", "-s 0",
                    "-0", "-s TERM", "-TERM", "-15", "-31", "-USR2", "-s USR2", "-INFO"])
  func validSignalsReachTheKernel(_ spec: String) async throws {
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n",
                  args: spec.split(separator: " ").map(String.init) + [Self.noSuchPid])
  }

  @Test(arguments: [(["-s", "FOO"], "FOO"), (["-FOO"], "FOO"), (["-SIG"], "SIG"), (["-s", "SIG"], "SIG"),
                    (["-s", "9"], "9"), (["-s", "1"], "1"), (["-s", "-9"], "-9"), (["-s", ""], ""),
                    (["-EXIT"], "EXIT"), (["-ZERO"], "ZERO"), (["-CLD"], "CLD"), (["-IOT"], "IOT"),
                    (["-RTMIN"], "RTMIN"), (["-s", "+1"], "+1"), (["-+1"], "+1"), (["-."], "."), (["-_"], "_"),
                    (["-"], ""), (["-é"], "é"), (["-HUPX"], "HUPX")])
  func unknownSignalNamesListTheSignals(_ args: [String], _ shown: String) async throws {
    try await run(status: 2, error: "kill: unknown signal \(shown); valid signals:\n" + Self.listing,
                  args: args + [Self.noSuchPid])
  }

  @Test(arguments: ["-9x", "-1a", "-0x9", "-1.5", "-12 "])
  func malformedSignalNumbersAreRejected(_ spec: String) async throws {
    try await run(status: 2, error: "kill: illegal signal number: \(spec.dropFirst())\n", args: [spec, Self.noSuchPid])
  }

  /// Numbers past the last signal are handed to the kernel, which refuses them.
  @Test(arguments: ["-32", "-999", "-2147483647"])
  func outOfRangeSignalNumbersAreInvalid(_ spec: String) async throws {
    try await run(status: 1, error: "kill: \(Self.noSuchPid): Invalid argument\n", args: [spec, Self.noSuchPid])
  }

  /// The signal number is truncated to an int, as the system does.
  @Test func hugeSignalNumbersWrapAround() async throws {
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n", args: ["-4294967297", Self.noSuchPid])
    try await run(status: 2, error: /kill: unknown signal 2147483648; valid signals:/, args: ["-2147483648", Self.noSuchPid])
  }

  @Test func onlyTheFirstOptionIsAnOption() async throws {
    try await run(status: 2, error: "kill: illegal process id: -s\n", args: ["-s", "HUP", "-s", "KILL", Self.noSuchPid])
  }

  @Test func doubleDashEndsTheOptions() async throws {
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n", args: ["--", Self.noSuchPid])
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n", args: ["-9", "--", Self.noSuchPid])
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n", args: ["-s", "HUP", "--", Self.noSuchPid])
  }

  /// With `--`, a negative operand is a process group.
  @Test func negativePidIsAProcessGroup() async throws {
    try await run(status: 1, error: "kill: -\(Self.noSuchPid): No such process\n", args: ["--", "-" + Self.noSuchPid])
  }

  // MARK: choosing the processes

  @Test(arguments: ["abc", "1x", "", "1.5", "0x10", "1 2", "99999999999", "-99999999999", "+", "-"])
  func illegalProcessIds(_ pid: String) async throws {
    try await run(status: 2, error: "kill: illegal process id: \(pid)\n", args: ["--", pid])
  }

  @Test(arguments: ["+99999999", " 99999999", "\t99999999", "099999999"])
  func processIdsFollowStrtol(_ pid: String) async throws {
    try await run(status: 1, error: "kill: \(pid): No such process\n", args: [pid])
  }

  @Test func everyMissingProcessIsReported() async throws {
    try await run(status: 1, error: "kill: 99999999: No such process\nkill: 99999998: No such process\n",
                  args: ["99999999", "99999998"])
  }

  /// A bad operand ends the run immediately, after the earlier operands were handled.
  @Test func anIllegalPidStopsTheRun() async throws {
    try await run(status: 2, error: "kill: 99999999: No such process\nkill: illegal process id: abc\n",
                  args: ["99999999", "abc", "99999998"])
  }

  @Test func signalZeroTestsForExistence() async throws {
    let me = String(getpid())
    try await run(args: ["-0", me])
    try await run(args: ["-s", "0", me])
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n", args: ["-0", Self.noSuchPid])
  }

  @Test func exitStatusIsOneIfAnyKillFails() async throws {
    let me = String(getpid())
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n", args: ["-0", me, Self.noSuchPid, me])
  }

  // MARK: actually delivering signals

  @Test(arguments: [[], ["-TERM"], ["-s", "TERM"], ["-15"], ["-s", "term"], ["-SIGTERM"]])
  func defaultAndExplicitTermKillTheProcess(_ args: [String]) async throws {
    let child = Self.spawnSleeper()
    #expect(child > 0)
    try await run(args: args + [String(child)])
    #expect(Self.terminationSignal(of: child) == SIGTERM)
  }

  @Test(arguments: [(["-9"], SIGKILL), (["-KILL"], SIGKILL), (["-s", "KILL"], SIGKILL), (["-HUP"], SIGHUP),
                    (["-1"], SIGHUP), (["-s", "INT"], SIGINT), (["-USR1"], SIGUSR1), (["-s", "usr2"], SIGUSR2),
                    (["-QUIT"], SIGQUIT), (["-ALRM"], SIGALRM)])
  func signalsAreDelivered(_ args: [String], _ expected: Int32) async throws {
    let child = Self.spawnSleeper()
    #expect(child > 0)
    try await run(args: args + [String(child)])
    #expect(Self.terminationSignal(of: child) == expected)
  }

  @Test func severalProcessesAtOnce() async throws {
    let a = Self.spawnSleeper()
    let b = Self.spawnSleeper()
    try await run(args: ["-9", String(a), String(b)])
    #expect(Self.terminationSignal(of: a) == SIGKILL)
    #expect(Self.terminationSignal(of: b) == SIGKILL)
  }

  @Test func theLiveProcessIsStillSignalledWhenAnotherFails() async throws {
    let child = Self.spawnSleeper()
    try await run(status: 1, error: "kill: \(Self.noSuchPid): No such process\n",
                  args: [Self.noSuchPid, String(child)])
    #expect(Self.terminationSignal(of: child) == SIGTERM)
  }
}
