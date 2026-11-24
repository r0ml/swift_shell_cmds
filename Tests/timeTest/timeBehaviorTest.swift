// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A directory of its own for a test.
final class TimeDirectory {
  let root: String

  init() {
    var template = Array("/tmp/timetestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  func path(_ name: String) -> String { root + "/" + name }

  func text(_ name: String) -> String? { (try? FilePath(path(name)).readAllBytes()).map { String(decoding: $0, as: UTF8.self) } }

  func write(_ name: String, _ text: String, mode: mode_t = 0o644) {
    let fd = open(path(name), O_CREAT | O_WRONLY | O_TRUNC, 0o644)
    _ = text.withCString { Darwin.write(fd, $0, strlen($0)) }
    close(fd)
    chmod(path(name), mode)
  }

  func remove() {
    if let d = opendir(root) {
      while let e = readdir(d) {
        let name = withUnsafePointer(to: &e.pointee.d_name) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
        if name != "." && name != ".." { unlink(path(name)); rmdir(path(name)) }
      }
      closedir(d)
    }
    rmdir(root)
  }
}

/// Serialized: `run` changes PATH for the whole process, and the timings want the machine to themselves.
@Suite("time behavior", .serialized) final class timeBehaviorTest : ShellTest {
  let cmd = "time"
  let suiteBundle = "shell_cmds_timeTest"

  static let usageText = "usage: time [-al] [-h | -p] [-o file] utility [argument ...]\n"
  /// The point is the one of the "C" locale.
  let env = ["LC_ALL": "C", "LC_NUMERIC": "C"]

  // The shapes of what is shown.
  static var plain: Regex<Substring> { /^ *\d+\.\d\d real +\d+\.\d\d user +\d+\.\d\d sys\n$/ }
  static var posix: Regex<Substring> { /^real \d+\.\d\d\nuser \d+\.\d\d\nsys \d+\.\d\d\n$/ }
  static var human: Regex<Substring> { /^\t(?:\d+d)?(?:\d+h)?(?:\d+m)?\d+\.\d\ds real\t\t(?:\d+d)?(?:\d+h)?(?:\d+m)?\d+\.\d\ds user\t\t(?:\d+d)?(?:\d+h)?(?:\d+m)?\d+\.\d\ds sys\n$/ }

  // MARK: usage

  @Test(arguments: ["-z", "-x", "-q"])
  func unknownOption(_ opt: String) async throws {
    try await run(status: 1, output: "", error: "time: illegal option -- \(opt.dropFirst())\n" + Self.usageText, args: opt, "true")
  }

  @Test func optionNeedsAnArgument() async throws {
    try await run(status: 1, output: "", error: "time: option requires an argument -- o\n" + Self.usageText, args: "-o")
  }

  @Test(arguments: [[String](), ["-p"], ["-l"], ["-h"], ["-a", "-p"]])
  func noCommandIsNothing(_ args: [String]) async throws {
    try await run(status: 0, output: "", error: "", args: args)
  }

  // MARK: showing the times

  @Test func defaultFormat() async throws {
    try await run(output: "", error: Self.plain, args: "true", env: env)
  }

  @Test(arguments: [["-p"], ["-pp"]])
  func posixFormat(_ opts: [String]) async throws {
    try await run(output: "", error: Self.posix, args: opts + ["true"], env: env)
  }

  @Test(arguments: [["-h"], ["-hh"]])
  func humanFormat(_ opts: [String]) async throws {
    try await run(output: "", error: Self.human, args: opts + ["true"], env: env)
  }

  @Test func posixWinsOverHuman() async throws {
    try await run(output: "", error: Self.posix, args: "-hp", "true", env: env)
    try await run(output: "", error: Self.posix, args: "-ph", "true", env: env)
  }

  @Test func realTimeIsMeasured() async throws {
    try await run(output: "", args: "-p", "sleep", "1.2", env: env) { po in
      let first = po.error.split(separator: "\n").first.map(String.init) ?? ""
      let seconds = Double(first.dropFirst(5)) ?? 0
      #expect(seconds >= 1.15 && seconds < 3, "\(first)")
    }
  }

  @Test func theCommandsOutputIsItsOwn() async throws {
    try await run(output: "out\n", args: "sh", "-c", "echo out; echo err >&2", env: env) { po in
      #expect(po.error.hasPrefix("err\n"))
    }
  }

  @Test func resourceUsage() async throws {
    let labels = ["maximum resident set size", "average shared memory size", "average unshared data size", "average unshared stack size",
                  "page reclaims", "page faults", "swaps", "block input operations", "block output operations", "messages sent",
                  "messages received", "signals received", "voluntary context switches", "involuntary context switches"]
    try await run(output: "", args: "-l", "true", env: env) { po in
      let lines = po.error.split(separator: "\n").map(String.init)
      #expect(lines.count >= 15)
      #expect(lines[0].contains("real"))
      for (line, label) in zip(lines.dropFirst(), labels) {
        // a number in a field of 20, two spaces, the label
        #expect(line.count == 22 + label.count, "\(line)")
        #expect(line.hasSuffix("  " + label), "\(line)")
        #expect(Int(line.dropLast(label.count + 2).drop { $0 == " " }) != nil, "\(line)")
      }
    }
  }

  // MARK: the output file

  @Test func outputFile() async throws {
    let d = TimeDirectory()
    defer { d.remove() }
    try await run(output: "", error: "", args: "-o", "times", "true", env: env, cd: FilePath(d.root))
    #expect(d.text("times")?.wholeMatch(of: Self.plain) != nil)
  }

  @Test func outputFileIsReplacedUnlessAppended() async throws {
    let d = TimeDirectory()
    defer { d.remove() }
    d.write("times", "PREVIOUS\n")
    try await run(output: "", error: "", args: "-a", "-o", "times", "-p", "true", env: env, cd: FilePath(d.root))
    let appended = try #require(d.text("times"))
    #expect(appended.hasPrefix("PREVIOUS\nreal "))
    try await run(output: "", error: "", args: "-o", "times", "-p", "true", env: env, cd: FilePath(d.root))
    #expect(d.text("times")?.wholeMatch(of: Self.posix) != nil)
  }

  @Test(arguments: [("/nonexistent/dir/times", "No such file or directory"), ("/etc", "Is a directory")])
  func outputFileThatCannotBeMade(_ name: String, _ why: String) async throws {
    try await run(status: 1, output: "", error: "time: \(name): \(why)\n", args: "-o", name, "true", env: env)
  }

  // MARK: the command

  @Test(arguments: [0, 1, 7, 42, 255])
  func exitStatusIsTheCommands(_ code: Int) async throws {
    try await run(status: code, output: "", error: Self.plain, args: "sh", "-c", "exit \(code)", env: env)
  }

  @Test func commandNotFound() async throws {
    try await run(status: 127, output: "", error: /^time: nosuchcmd_zz: No such file or directory\n *\d+\.\d\d real +\d+\.\d\d user +\d+\.\d\d sys\n$/, args: "nosuchcmd_zz", env: env)
    try await run(status: 127, output: "", error: /^time: \/nonexistent\/x: No such file or directory\n/, args: "/nonexistent/x", env: env)
  }

  @Test(arguments: ["/etc/passwd", "/tmp"])
  func commandThatCannotBeRun(_ name: String) async throws {
    try await run(status: 126, output: "", args: name, env: env) { po in
      #expect(po.error.hasPrefix("time: \(name): Permission denied\n"))
    }
  }

  @Test func argumentsAreGivenToTheCommand() async throws {
    try await run(output: "a b c d\n", args: "echo", "a", "b", "c d", env: env) { po in
      #expect(po.error.wholeMatch(of: Self.plain) != nil)
    }
  }

  @Test func optionsOfTheCommandAreItsOwn() async throws {
    try await run(output: "-p -l\n", args: "echo", "-p", "-l", env: env)
  }

  @Test func optionsAfterTheCommandAreNotOptions() async throws {
    try await run(output: "", args: "true", "-p", env: env) { po in
      #expect(po.error.wholeMatch(of: Self.plain) != nil)
    }
  }

  @Test func doubleDashEndsOptions() async throws {
    try await run(output: "", error: Self.posix, args: "-p", "--", "true", env: env)
  }

  // MARK: ending by a signal

  /// The signal that can't be caught can't be put back to its default either: time ends with the status of failure.
  @Test func commandKilledBySigkill() async throws {
    try await run(status: 1, output: "", args: "sh", "-c", "kill -9 $$", env: env) { po in
      #expect(po.error.hasPrefix("time: command terminated abnormally\n"))
      #expect(po.error.hasSuffix("time: signal: Invalid argument\n"))
      #expect(po.error.contains(" real "))
    }
  }

  @Test(arguments: [(SIGTERM, "kill -TERM $$"), (SIGHUP, "kill -HUP $$")])
  func commandKilledBySignal(_ sig: Int32, _ script: String) async throws {
    // time ends in the same way: that is the status of the run
    try await run(status: Int(128 + sig), output: "", args: "sh", "-c", script, env: env) { po in
      #expect(po.error.hasPrefix("time: command terminated abnormally\n"))
      #expect(po.error.dropFirst("time: command terminated abnormally\n".count).wholeMatch(of: Self.plain) != nil)
    }
  }

  // MARK: reports

  /// Starts time with a pipe for its standard output; the caller sends the signal and reads what came out.
  func startTiming(_ args: [String]) throws -> (pid: pid_t, outputFD: Int32) {
    guard let path = searchPath(for: "time") else { throw POSIXErrno(ENOENT) }
    var fds: [Int32] = [0, 0]
    guard pipe(&fds) == 0 else { throw POSIXErrno(errno) }
    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_adddup2(&actions, fds[1], 1)
    posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // nothing else is passed on to the child (the other tests' pipes, for one), and the signals are as usual
    var defaults = sigset_t()
    sigfillset(&defaults)
    var noSignals = sigset_t()
    sigemptyset(&noSignals)
    posix_spawnattr_setsigdefault(&attr, &defaults)
    posix_spawnattr_setsigmask(&attr, &noSignals)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
    var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
    defer { for p in argv { free(p) } }
    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, environ)
    close(fds[1])
    guard rc == 0 else { close(fds[0]); throw POSIXErrno(rc) }
    return (pid, fds[0])
  }

  @Test func progressIsReported() async throws {
    let (pid, fd) = try startTiming(["sleep", "1.5"])
    defer { close(fd) }
    try await Task.sleep(for: .milliseconds(500))
    kill(pid, SIGINFO)
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    #expect(status == 0)
    var buffer = [UInt8](repeating: 0, count: 1024)
    let n = read(fd, &buffer, buffer.count)
    let text = String(decoding: buffer[0..<max(n, 0)], as: UTF8.self)
    // the report of the times so far is on the standard output (the final one is on the error output)
    #expect(text.wholeMatch(of: Self.plain) != nil, "\(text)")
  }

  @Test func interruptGoesToTheCommand() async throws {
    let (pid, fd) = try startTiming(["sleep", "30"])
    defer { close(fd) }
    try await Task.sleep(for: .milliseconds(500))
    kill(pid, SIGINT)
    var status: Int32 = 0
    for _ in 0..<100 {
      if waitpid(pid, &status, WNOHANG) == pid { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    // the signal is passed to the command, which dies of it, and so does time
    if (status & 0x7f) == 0 {
      Issue.record("time did not end of the signal: status \(status)")
      kill(pid, SIGKILL)
      waitpid(pid, &status, 0)
    } else {
      #expect(status & 0x7f == SIGINT)
    }
  }
}
