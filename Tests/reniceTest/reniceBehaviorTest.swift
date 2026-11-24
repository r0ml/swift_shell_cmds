// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A sleeping process in a process group of its own: the only thing these tests ever change the priority of.
final class Sleeper {
  let pid: pid_t

  init() {
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // a group of its own, and nothing passed on to it (the other tests' pipes, for one)
    posix_spawnattr_setpgroup(&attr, 0)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    for fd in 0...2 {
      posix_spawn_file_actions_addopen(&actions, Int32(fd), "/dev/null", fd == 0 ? O_RDONLY : O_WRONLY, 0)
    }
    var argv: [UnsafeMutablePointer<CChar>?] = [strdup("sleep"), strdup("120"), nil]
    defer { for a in argv { free(a) } }
    var p: pid_t = 0
    let rc = posix_spawn(&p, "/bin/sleep", &actions, &attr, argv, environ)
    precondition(rc == 0 && p > 0, "could not start the test process: \(rc)")
    pid = p
  }

  var pgid: pid_t { getpgid(pid) }

  /// The nice value of the process.
  var nice: Int { Int(getpriority(PRIO_PROCESS, id_t(pid))) }

  func stop() {
    kill(pid, SIGKILL)
    var status: Int32 = 0
    waitpid(pid, &status, 0)
  }
}

extension reniceTest {

  static let usageText = """
    usage: renice priority [[-p] pid ...] [[-g] pgrp ...] [[-u] user ...]
           renice -n increment [[-p] pid ...] [[-g] pgrp ...] [[-u] user ...]

    """

  /// What the test runner has, which is what the processes it starts begin with.
  static var baseline: Int { Int(getpriority(PRIO_PROCESS, 0)) }

  // MARK: usage and bad arguments

  @Test(arguments: [[String](), ["-n"], ["-n", "1", "-n", "2", "123"], ["5", "-n", "3", "123"], ["-n", "5", "-p", "-n"], ["-p", "-n"], ["-p", "-n", "3", "-n", "4", "123"], ["-g", "-n", "3", "-n", "123"]])
  func usageErrors(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Self.usageText, args: args)
  }

  @Test(arguments: [(["x", "123"], "priority argument x is invalid."), (["5x", "123"], "priority argument 5x is invalid."),
                    (["0x5", "123"], "priority argument 0x5 is invalid."), (["-x", "5", "123"], "priority argument -x is invalid."),
                    (["-h"], "priority argument -h is invalid."), (["-n", "-n"], "priority argument -n is invalid."), (["-n", "-n", "3", "123"], "priority argument -n is invalid."),
                    (["-n", "-p", "3", "123"], "priority argument -p is invalid."), (["-p", "-n", "-n", "3", "123"], "priority argument -n is invalid."),
                    (["-p", "-n", "-p", "3", "123"], "priority argument -p is invalid."),
                    (["-n", "-g", "3", "123"], "priority argument -g is invalid."),
                    (["--", "-n", "5", "123"], "priority argument -n is invalid."),
                    (["99999999999", "123"], "priority argument 99999999999 is out of range."),
                    (["2147483648", "99999999"], "priority argument 2147483648 is out of range."),
                    (["-2147483649", "99999999"], "priority argument -2147483649 is out of range."),
                    (["5", "x"], "pid argument x is invalid."), (["5", "-x"], "pid argument -x is invalid."),
                    (["5", "0x10"], "pid argument 0x10 is invalid."), (["5", "1e3"], "pid argument 1e3 is invalid."),
                    (["5", "--", "-p"], "pid argument -p is invalid."), (["5", "-g", "x"], "pid argument x is invalid."),
                    (["5", "99999999999"], "pid argument 99999999999 is out of range."),
                    (["5", "2147483648"], "pid argument 2147483648 is out of range."),
                    (["5", "-1"], "-1: bad value"), (["5", "-u", "-1"], "-1: bad value"), (["5", "-g", "-1"], "-1: bad value"),
                    (["5", "-u", "nosuchuser_zz"], "uid argument nosuchuser_zz is invalid."),
                    (["5", "-u", "x"], "uid argument x is invalid."),
                    (["5", "-u", "99999999999"], "uid argument 99999999999 is out of range."),
                    (["5", "-u", "4294967295"], "uid argument 4294967295 is out of range."),
                    (["5", "99999999"], "99999999: getpriority: No such process"),
                    (["5", "-g", "99999999"], "99999999: getpriority: No such process"),
                    (["5", "-u", "99999999"], "99999999: getpriority: No such process"),
                    (["5", "007"], "7: getpriority: No such process")])
  func badArguments(_ args: [String], _ message: String) async throws {
    try await run(status: 1, output: "", error: "renice: \(message)\n", args: args)
  }

  @Test(arguments: [["5"], ["-n", "5"], ["5", "-p"], ["5", "-u"], ["5", "-g"], ["-n", "5", "--"], ["5", "--"], ["-p", "5"], ["-n", "123"]])
  func nothingToChange(_ args: [String]) async throws {
    try await run(output: "", error: "", args: args)
  }

  // MARK: changing a process

  @Test(arguments: [3, 7, 15])
  func absolutePriority(_ extra: Int) async throws {
    let s = Sleeper()
    defer { s.stop() }
    let target = min(Self.baseline + extra, 20)
    try await run(output: "", error: "", args: String(target), String(s.pid))
    #expect(s.nice == target)
  }

  @Test func relativePriority() async throws {
    let s = Sleeper()
    defer { s.stop() }
    let start = s.nice
    try await run(args: "-n", "2", String(s.pid))
    try await run(args: "-p", "-n", "3", String(s.pid))
    try await run(args: "-n", "1", "-p", String(s.pid))
    #expect(s.nice == min(start + 6, 20))
  }

  /// A priority beyond the limits is taken to the limit.
  @Test(arguments: [[String]()])
  func beyondTheLimits(_ extra: [String]) async throws {
    let s = Sleeper()
    defer { s.stop() }
    try await run(args: "100", String(s.pid))
    #expect(s.nice == 20)
    let t = Sleeper()
    defer { t.stop() }
    try await run(args: "-n", "100", String(t.pid))
    #expect(t.nice == 20)
    let u = Sleeper()
    defer { u.stop() }
    try await run(args: "21", String(u.pid))
    #expect(u.nice == 20)
  }

  /// strtol is what reads the priority: white space and a plus sign are fine, so is a zero in front.
  @Test(arguments: [" 5", "+5", "05", "005"])
  func priorityForms(_ form: String) async throws {
    let s = Sleeper()
    defer { s.stop() }
    try await run(args: form, String(s.pid))
    #expect(s.nice == 5 || Self.baseline > 5)
  }

  @Test func pidWithLeadingZeros() async throws {
    let s = Sleeper()
    defer { s.stop() }
    let target = min(Self.baseline + 4, 20)
    try await run(args: String(target), "0" + String(s.pid))
    #expect(s.nice == target)
  }

  /// Only the super-user may lower a nice value.
  @Test(arguments: [0, -5, -20])
  func lowering(_ priority: Int) async throws {
    if getuid() == 0 { return }
    let s = Sleeper()
    defer { s.stop() }
    try await run(args: "10", String(s.pid))
    try await run(status: 1, error: "renice: \(s.pid): setpriority: Permission denied\n", args: String(priority), String(s.pid))
    #expect(s.nice == 10)
    try await run(status: 1, error: "renice: \(s.pid): setpriority: Permission denied\n", args: "-n", String(priority - 20), String(s.pid))
    #expect(s.nice == 10)
  }

  @Test func theSamePriorityAgainIsFine() async throws {
    let s = Sleeper()
    defer { s.stop() }
    let target = min(Self.baseline + 5, 20)
    try await run(output: "", error: "", args: String(target), String(s.pid))
    try await run(output: "", error: "", args: String(target), String(s.pid))
    #expect(s.nice == target)
  }

  // MARK: several at a time

  @Test func severalProcesses() async throws {
    let a = Sleeper(), b = Sleeper()
    defer { a.stop(); b.stop() }
    let target = min(Self.baseline + 6, 20)
    try await run(args: String(target), String(a.pid), "-p", String(b.pid))
    #expect(a.nice == target && b.nice == target)
  }

  /// The ones before and after a bad one are still changed; the exit status says something was wrong.
  @Test func aBadOperandDoesNotStopTheRest() async throws {
    let a = Sleeper(), b = Sleeper()
    defer { a.stop(); b.stop() }
    let target = min(Self.baseline + 6, 20)
    try await run(status: 1, error: "renice: pid argument x is invalid.\n", args: String(target), String(a.pid), "x", String(b.pid))
    #expect(a.nice == target && b.nice == target)
  }

  @Test func processGroup() async throws {
    let s = Sleeper()
    defer { s.stop() }
    let target = min(Self.baseline + 4, 20)
    try await run(args: "-g", String(target), String(s.pgid))
    #expect(s.nice == target)
    try await run(args: "-n", "1", "-g", String(s.pgid))
    #expect(s.nice == min(target + 1, 20))
  }

  @Test func kindOfIdentifierSticksUntilChanged() async throws {
    let s = Sleeper()
    defer { s.stop() }
    let target = min(Self.baseline + 4, 20)
    // -g applies to what follows; -p goes back to processes
    try await run(args: String(target), "-g", String(s.pgid), "-p", String(s.pid))
    #expect(s.nice == target)
  }

  @Test func theGroupLeaderIsTheProcessToo() async throws {
    let s = Sleeper()
    defer { s.stop() }
    #expect(s.pgid == s.pid)
    let target = min(Self.baseline + 3, 20)
    try await run(args: String(target), "-p", String(s.pgid))
    #expect(s.nice == target)
  }

  // MARK: delimiters

  @Test func doubleDash() async throws {
    let s = Sleeper()
    defer { s.stop() }
    let target = min(Self.baseline + 2, 20)
    try await run(args: "--", String(target), String(s.pid))
    #expect(s.nice == target)
    // after it, -p and the like are operands
    try await run(status: 1, error: "renice: pid argument -p is invalid.\n", args: String(target), "--", "-p", String(s.pid))
  }
}
