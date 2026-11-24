// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// What a run of yes came to: how it ended, what it wrote (the first part), and what it said on the error output.
struct YesRun {
  var status: Int32
  var output: [UInt8]
  var error: String
}

/// yes never ends by itself, so these tests start it, read as much of what it says as they want, and close the pipe:
/// that is what ends it.
@Suite("yes", .serialized) final class yesTest : ShellTest {
  let cmd = "yes"
  let suiteBundle = "shell_cmds_yesTest"

  func yesExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  /// Runs yes with the arguments, reads `count` bytes of its output, and closes the pipe.  With `ignoringPipe` the
  /// signal for a pipe with no reader is ignored, as a shell can arrange.
  func runYes(_ args: [String], reading count: Int = 100_000, ignoringPipe: Bool = false) throws -> YesRun {
    let path = try yesExecutable()
    var out: [Int32] = [0, 0]
    var err: [Int32] = [0, 0]
    guard pipe(&out) == 0, pipe(&err) == 0 else { throw POSIXErrno(errno) }

    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_adddup2(&actions, out[1], 1)
    posix_spawn_file_actions_adddup2(&actions, err[1], 2)
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // nothing else is passed on (the other tests' pipes, for one), and the signals are as stated
    var defaults = sigset_t()
    sigfillset(&defaults)
    sigdelset(&defaults, SIGKILL)
    sigdelset(&defaults, SIGSTOP)
    // (an ignored signal stays ignored through the exec: so it is ignored here, for the spawn)
    if ignoringPipe {
      sigdelset(&defaults, SIGPIPE)
    }
    var noSignals = sigset_t()
    sigemptyset(&noSignals)
    posix_spawnattr_setsigdefault(&attr, &defaults)
    posix_spawnattr_setsigmask(&attr, &noSignals)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))

    var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
    defer { for p in argv { free(p) } }
    var pid: pid_t = 0
    let before = ignoringPipe ? signal(SIGPIPE, SIG_IGN) : nil
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, environ)
    if ignoringPipe { signal(SIGPIPE, before) }
    close(out[1])
    close(err[1])
    guard rc == 0 else { close(out[0]); close(err[0]); throw POSIXErrno(rc) }

    var output = [UInt8]()
    var buffer = [UInt8](repeating: 0, count: 65536)
    while output.count < count {
      let n = read(out[0], &buffer, buffer.count)
      if n <= 0 { break }
      output += buffer[0..<n]
    }
    close(out[0])

    // how it ends (it is killed if it doesn't)
    var status: Int32 = 0
    var ended = false
    for _ in 0..<100 {
      if waitpid(pid, &status, WNOHANG) == pid { ended = true; break }
      usleep(50_000)
    }
    if !ended {
      kill(pid, SIGKILL)
      waitpid(pid, &status, 0)
    }
    var errorBuffer = [UInt8](repeating: 0, count: 1024)
    let m = read(err[0], &errorBuffer, errorBuffer.count)
    close(err[0])
    let code = !ended ? -1 : (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
    return YesRun(status: code, output: Array(output.prefix(count)), error: String(decoding: errorBuffer[0..<max(m, 0)], as: UTF8.self))
  }

  /// The bytes it is to say: the line as many times as it takes.
  func expected(_ line: [UInt8], count: Int) -> [UInt8] {
    var result = [UInt8]()
    while result.count < count { result += line }
    return Array(result.prefix(count))
  }

  @Test func saysYByDefault() throws {
    let r = try runYes([])
    #expect(r.output == expected(Array("y\n".utf8), count: r.output.count))
    #expect(r.output.count == 100_000)
  }

  @Test(arguments: [["foo"], [""], ["-n"], ["--help"], ["-"], ["--"], ["a b  c"], ["é世界"], ["%s%d"], ["\\n"], ["x"]])
  func saysTheArgument(_ args: [String]) throws {
    let r = try runYes(args)
    #expect(r.output.count == 100_000)
    #expect(r.output == expected(Array(args[0].utf8) + [10], count: r.output.count))
  }

  /// All the arguments are said, with a space between them.
  @Test(arguments: [(["a", "b"], "a b"), (["a", "b", "c"], "a b c"), (["-e", "x"], "-e x"), (["x y", "z"], "x y z"),
                    (["a", "", "b"], "a  b"), (["a", ""], "a "), (["a", "", ""], "a  ")])
  func saysAllTheArguments(_ args: [String], _ line: String) throws {
    let r = try runYes(args)
    #expect(r.output == expected(Array(line.utf8) + [10], count: r.output.count))
  }

  /// Empty arguments at the start aren't said.
  @Test(arguments: [(["", "a"], "a"), (["", "", "a"], "a"), (["", "a", ""], "a "), (["", ""], ""), (["", "", ""], "")])
  func emptyArgumentsInFront(_ args: [String], _ line: String) throws {
    let r = try runYes(args)
    #expect(r.output == expected(Array(line.utf8) + [10], count: r.output.count))
  }

  /// Lines around the size of the buffer it writes with, and longer than it.
  @Test(arguments: [100, 4095, 4096, 8190, 8191, 8192, 8193, 20_000])
  func longLines(_ length: Int) throws {
    let word = String(repeating: "x", count: length)
    let r = try runYes([word], reading: 200_000)
    #expect(r.output.count == 200_000)
    #expect(r.output == expected(Array(word.utf8) + [10], count: r.output.count))
  }

  @Test func argumentsThatAreNotText() throws {
    // (an argument can be passed as the bytes it is made of, but this has to be text: the bytes are of two letters)
    let r = try runYes(["ab\u{ff}cd"])
    #expect(r.output == expected(Array("ab\u{ff}cd".utf8) + [10], count: r.output.count))
  }

  @Test func endsByThePipeBeingClosed() throws {
    let r = try runYes([])
    #expect(r.status == 128 + SIGPIPE)
    #expect(r.error == "")
  }

  @Test(arguments: [[String](), ["foo"], ["x y"]])
  func saysSoWhenThePipeIsIgnored(_ args: [String]) throws {
    let r = try runYes(args, ignoringPipe: true)
    #expect(r.status == 1)
    #expect(r.error == "yes: stdout: Broken pipe\n")
  }
}
