// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A directory of its own for a test, with helpers for reading and writing what is in it.
final class ScriptDirectory {
  let root: String

  init() {
    var template = Array("/tmp/scripttestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  func path(_ name: String) -> String { root + "/" + name }

  func read(_ name: String) -> [UInt8]? { try? FilePath(path(name)).readAllBytes() }

  func text(_ name: String) -> String? { read(name).map { String(decoding: $0, as: UTF8.self) } }

  func write(_ name: String, _ bytes: [UInt8]) {
    let fd = open(path(name), O_CREAT | O_WRONLY | O_TRUNC, 0o644)
    _ = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
    close(fd)
  }

  func mode(_ name: String) -> mode_t? {
    var st = stat()
    return stat(path(name), &st) == 0 ? st.st_mode & 0o7777 : nil
  }

  func remove() {
    if let d = opendir(root) {
      while let e = readdir(d) {
        let name = withUnsafePointer(to: &e.pointee.d_name) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
        if name != "." && name != ".." { unlink(path(name)) }
      }
      closedir(d)
    }
    rmdir(root)
  }
}

/// The lines of a text, split at each newline (a return in front of one stays with its line).
func scriptLines(_ text: String) -> [String] {
  Array(text.utf8).split(separator: 10, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
}

/// The records a typescript made with -r is made of.
struct ScriptRecord: Equatable {
  var length: UInt64
  var direction: UInt8
  var data: [UInt8]
}

func scriptStamp(_ length: UInt64, _ sec: UInt64, _ usec: UInt32, _ direction: Character, bigEndian: Bool = false) -> [UInt8] {
  func bytes<T: FixedWidthInteger>(_ v: T) -> [UInt8] {
    withUnsafeBytes(of: bigEndian ? v.bigEndian : v.littleEndian) { Array($0) }
  }
  return bytes(length) + bytes(sec) + bytes(usec) + bytes(UInt32(direction.asciiValue ?? 0))
}

func scriptRecords(_ bytes: [UInt8]) -> [ScriptRecord] {
  var result = [ScriptRecord]()
  var i = 0
  while i + 24 <= bytes.count {
    let length = bytes[i..<i + 8].reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let direction = bytes[i + 20]
    let end = i + 24 + Int(length)
    result.append(ScriptRecord(length: length, direction: direction, data: Array(bytes[i + 24..<min(end, bytes.count)])))
    i = end
  }
  return result
}

/// Serialized: `run` changes PATH for the whole process.
@Suite("script behavior", .serialized) final class scriptBehaviorTest : ShellTest {
  let cmd = "script"
  let suiteBundle = "shell_cmds_scriptTest"

  /// What the command's terminal shows for the end of file the script puts there when its input is at an end.
  static let eof = "^D\u{8}\u{8}"

  static let usageText = """
    usage: script [-aeFkpqr] [-t time] [file [command ...]]
           script -p [-deq] [-T fmt] [file]

    """

  /// The path of the script under test, found the way `run` finds it.
  func scriptExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  /// Runs script with a terminal (with 30 rows and 100 columns) as its standard input, output and error, sending
  /// `input` once the session has started.  Returns the exit status and what was shown on the terminal.
  func runOnTerminal(_ args: [String], in d: ScriptDirectory, input: [UInt8] = [], after marker: String = "") throws -> (Int32, [UInt8]) {
    let path = try scriptExecutable()
    let master = posix_openpt(O_RDWR | O_NOCTTY)
    guard master >= 0, grantpt(master) == 0, unlockpt(master) == 0, let slaveName = ptsname(master) else {
      throw POSIXErrno(errno)
    }
    defer { close(master) }
    var size = winsize(ws_row: 30, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
    // kept open for the whole run: the size is forgotten when the last user of the slave goes
    let slave = open(slaveName, O_RDWR | O_NOCTTY)
    ioctl(slave, UInt(0x8008_7467), &size)
    defer { close(slave) }

    var actions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_addchdir_np(&actions, d.root)
    for fd in Int32(0)...2 {
      posix_spawn_file_actions_addopen(&actions, fd, slaveName, O_RDWR | O_NOCTTY, 0)
    }
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // nothing else is passed on to the child (the other tests' pipes, for one)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))

    var environment = Environment.getenv()
    environment["SHELL"] = "/bin/sh"
    var envp: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    var argv: [UnsafeMutablePointer<CChar>?] = ([path] + args).map { strdup($0) } + [nil]
    defer { for p in envp + argv { free(p) } }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, path, &actions, &attr, argv, envp)
    guard rc == 0 else { throw POSIXErrno(rc) }

    var shown = [UInt8]()
    var buffer = [UInt8](repeating: 0, count: 4096)
    var sent = false
    var status: Int32 = 0
    let flags = fcntl(master, F_GETFL)
    _ = fcntl(master, F_SETFL, flags | O_NONBLOCK)
    for _ in 0..<400 {
      var p = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
      if poll(&p, 1, 50) > 0 {
        let n = read(master, &buffer, buffer.count)
        if n > 0 {
          shown += buffer[0..<n]
          if !sent && !input.isEmpty && String(decoding: shown, as: UTF8.self).contains(marker) {
            sent = true
            _ = input.withUnsafeBytes { Darwin.write(master, $0.baseAddress, $0.count) }
          }
        }
      }
      if waitpid(pid, &status, WNOHANG) == pid {
        // what is left to read
        while true {
          let n = read(master, &buffer, buffer.count)
          if n <= 0 { break }
          shown += buffer[0..<n]
        }
        return ((status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f), shown)
      }
    }
    // too long: give up on it
    kill(pid, SIGKILL)
    waitpid(pid, &status, 0)
    return (-1, shown)
  }

  // MARK: usage

  @Test func unknownOption() async throws {
    try await run(withStdin: "", status: 1, output: "", error: "script: illegal option -- z\n" + Self.usageText, args: "-z")
  }

  @Test func missingOptionArgument() async throws {
    try await run(withStdin: "", status: 1, output: "", error: "script: option requires an argument -- t\n" + Self.usageText, args: "-t")
  }

  @Test func invalidFlushTime() async throws {
    try await run(withStdin: "", status: 1, output: "", error: "script: invalid flush time -5: Undefined error: 0\n", args: "-t", "-5")
  }

  // MARK: files that cannot be used

  @Test(arguments: ["/nonexistent/dir/file", "/etc"])
  func unusableTypescript(_ file: String) async throws {
    let why = file == "/etc" ? "Is a directory" : "No such file or directory"
    try await run(withStdin: "", status: 1, output: "", error: "script: \(file): \(why)\n", args: "-q", file, "true")
  }

  @Test func playbackOfAMissingFile() async throws {
    try await run(withStdin: "", status: 1, output: "", error: "script: /nonexistent/file: No such file or directory\n", args: "-p", "/nonexistent/file")
  }

  // MARK: running a command

  @Test func theCommandsOutputIsShownAndRecorded() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let shown = "\(Self.eof)a\r\nb\r\n"
    try await run(withStdin: "", status: 3, output: shown, error: "", args: "-q", "out", "sh", "-c", "echo a; echo b >&2; exit 3", cd: FilePath(d.root))
    #expect(d.text("out") == shown)
  }

  @Test func theMessagesAndTheHeadersOfTheTypescript() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", args: "out", "echo", "hi", cd: FilePath(d.root)) { po in
      // (when the messages are shown depends on how output is buffered)
      let out = String(decoding: po.data, as: UTF8.self)
      #expect(out.contains("\(Self.eof)hi\r\n"))
      #expect(out.contains("Script started, output file is out\n"))
      #expect(out.contains("\nScript done, output file is out\n"))
      #expect(out.count == "\(Self.eof)hi\r\nScript started, output file is out\n\nScript done, output file is out\n".count)
    }
    let file = try #require(d.text("out"))
    let lines = scriptLines(file)
    #expect(lines.count == 7)
    #expect(lines[0].hasPrefix("Script started on "))
    #expect(lines[1] == "Command: echo hi")
    #expect(lines[2] == "\(Self.eof)hi\r")
    #expect(lines[3] == "")
    #expect(lines[4] == "Command exit status: 0")
    #expect(lines[5].hasPrefix("Script done on "))
    #expect(lines[6] == "")
  }

  @Test func theCommandIsListedWithItsArguments() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", args: "out", "printf", "%s %s\\n", "a b", "c", cd: FilePath(d.root))
    #expect(d.text("out")?.contains("Command: printf %s %s\\n a b c\n") == true)
    #expect(d.text("out")?.contains("a b c\r\n") == true)
  }

  @Test(arguments: [0, 1, 7, 100, 255])
  func exitStatusIsTheCommands(_ code: Int) async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", status: code, args: "-q", "out", "sh", "-c", "exit \(code)", cd: FilePath(d.root))
    try await run(withStdin: "", status: code, args: "-q", "-e", "out", "sh", "-c", "exit \(code)", cd: FilePath(d.root))
  }

  @Test(arguments: [(SIGKILL, "kill -9 $$"), (SIGTERM, "kill -TERM $$"), (SIGHUP, "kill -HUP $$")])
  func killedCommandGivesTheSignalNumber(_ sig: Int32, _ script: String) async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", status: Int(sig), args: "-q", "out", "sh", "-c", script, cd: FilePath(d.root))
  }

  @Test(arguments: [("nosuchcmd_zz", "No such file or directory"), ("/etc/passwd", "Permission denied")])
  func commandThatCannotBeRun(_ command: String, _ why: String) async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    // the complaint is the command's, so it is on the terminal
    let shown = "\(Self.eof)script: \(command): \(why)\r\n"
    try await run(withStdin: "", status: 1, output: shown, error: "", args: "-q", "out", command, cd: FilePath(d.root))
    #expect(d.text("out") == shown)
  }

  @Test func theCommandKnowsTheTypescript() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", output: "\(Self.eof)my file\r\n", args: "-q", "my file", "sh", "-c", "echo $SCRIPT", cd: FilePath(d.root))
  }

  @Test func theCommandHasATerminalAsEverything() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", output: "\(Self.eof)alltty\r\n", args: "-q", "out", "sh", "-c", "test -t 0 && test -t 1 && test -t 2 && echo alltty", cd: FilePath(d.root))
  }

  @Test func theCommandHasAControllingTerminalOfItsOwnSession() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", output: "\(Self.eof)ok\r\n", args: "-q", "out", "sh", "-c", "[ \"$(ps -o tty= -p $$)\" != '??' ] && echo ok", cd: FilePath(d.root))
  }

  // MARK: input

  @Test func inputIsGivenToTheCommand() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let (status, _) = try runOnTerminal(["-q", "out", "sh", "-c", "echo ready; read x; echo got:$x"], in: d, input: Array("hi there\n".utf8), after: "ready")
    #expect(status == 0)
    #expect(d.text("out")?.contains("got:hi there\r\n") == true)
  }

  /// What is typed is recorded only because the terminal echoes it: with -k it is recorded when it isn't echoed.
  @Test(arguments: [false, true])
  func keysAreRecordedWithK(_ keys: Bool) async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let (status, _) = try runOnTerminal((keys ? ["-q", "-k"] : ["-q"]) + ["out", "sh", "-c", "stty -echo; echo ready; read x; echo got:$x"], in: d,
                                        input: Array("secret\n".utf8), after: "ready")
    #expect(status == 0)
    let file = try #require(d.text("out"))
    #expect(file.contains("got:secret\r\n"))
    #expect(file.contains("secret\nready") == false)
    #expect(file.contains("ready\r\nsecret\n") == keys)
  }

  // MARK: the typescript

  @Test func typescriptIsReplacedUnlessAppended() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("out", Array("previous\n".utf8))
    try await run(withStdin: "", args: "-q", "-a", "out", "echo", "added", cd: FilePath(d.root))
    #expect(d.text("out") == "previous\n\(Self.eof)added\r\n")
    try await run(withStdin: "", args: "-q", "out", "echo", "replaced", cd: FilePath(d.root))
    #expect(d.text("out") == "\(Self.eof)replaced\r\n")
  }

  @Test func appendingCreatesTheFile() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", args: "-q", "-a", "out", "echo", "x", cd: FilePath(d.root))
    #expect(d.text("out") == "\(Self.eof)x\r\n")
  }

  @Test func defaultTypescriptName() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    // with no command, it is the shell that is run
    try await run(withStdin: "", args: "-q", env: ["SHELL": "/bin/sh"], cd: FilePath(d.root))
    #expect(d.exists("typescript"))
  }

  @Test func theFileCreatedIsReadableByEveryone() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let old = umask(0o022)
    defer { umask(old) }
    try await run(withStdin: "", args: "-q", "out", "true", cd: FilePath(d.root))
    #expect(d.mode("out") == 0o644)
  }

  @Test(arguments: [["-F"], ["-t", "0"], ["-t", "1"], ["-t", "abc"], ["-e"], ["-F", "-t", "0", "-k"]])
  func optionsThatChangeNothingVisible(_ extra: [String]) async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", output: "\(Self.eof)hi\r\n", args: ["-q"] + extra + ["out", "echo", "hi"], cd: FilePath(d.root))
    #expect(d.text("out") == "\(Self.eof)hi\r\n")
  }

  // MARK: raw records

  @Test func rawRecords() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", args: "-q", "-r", "out", "echo", "hi", cd: FilePath(d.root))
    let records = scriptRecords(try #require(d.read("out")))
    // (the output may come in more than one piece)
    let directions = records.map(\.direction)
    #expect(directions.first == UInt8(ascii: "s") && directions.last == UInt8(ascii: "e"))
    #expect(directions.dropFirst().dropLast().allSatisfy { $0 == UInt8(ascii: "o") })
    #expect(records.first?.length == 0 && records.last?.length == 0)
    #expect(String(decoding: records.filter { $0.direction == UInt8(ascii: "o") }.flatMap(\.data), as: UTF8.self) == "\(Self.eof)hi\r\n")
    #expect(records.allSatisfy { $0.length == UInt64($0.data.count) })
  }

  @Test func rawRecordsHaveTheInput() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "typed\n", args: "-q", "-r", "out", "cat", cd: FilePath(d.root))
    let records = scriptRecords(try #require(d.read("out")))
    let input = records.filter { $0.direction == UInt8(ascii: "i") }.flatMap(\.data)
    #expect(String(decoding: input, as: UTF8.self) == "typed\n")
    let output = records.filter { $0.direction == UInt8(ascii: "o") }.flatMap(\.data)
    #expect(String(decoding: output, as: UTF8.self).contains("typed\r\n"))
  }

  @Test func rawRecordsHaveNoTextHeaders() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", args: "-r", "out", "echo", "hi", cd: FilePath(d.root)) { po in
      let out = String(decoding: po.data, as: UTF8.self)
      #expect(out.contains("Script started, output file is out\n"))
      #expect(out.contains("\nScript done, output file is out\n"))
    }
    let bytes = try #require(d.read("out"))
    #expect(!String(decoding: bytes, as: UTF8.self).contains("Script started on"))
  }

  @Test func recordedTimeIsNow() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let before = UInt64(time(nil))
    try await run(withStdin: "", args: "-q", "-r", "out", "echo", "hi", cd: FilePath(d.root))
    let bytes = try #require(d.read("out"))
    let sec = bytes[8..<16].reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    #expect(sec >= before && sec <= before + 30)
  }

  // MARK: playback

  /// Records: started, two lines of output a second apart, input, done.
  func sampleRecording() -> [UInt8] {
    scriptStamp(0, 1_700_000_000, 0, "s")
      + scriptStamp(5, 1_700_000_000, 500, "o") + Array("one\r\n".utf8)
      + scriptStamp(2, 1_700_000_001, 0, "i") + Array("x\n".utf8)
      + scriptStamp(5, 1_700_000_003, 0, "o") + Array("two\r\n".utf8)
      + scriptStamp(0, 1_700_000_003, 0, "e")
  }

  @Test func playback() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", sampleRecording())
    // the messages are held back until the end, as they are in a recording
    try await run(withStdin: "", args: "-p", "-d", "rec", env: ["TZ": "UTC"], cd: FilePath(d.root)) { po in
      let out = String(decoding: po.data, as: UTF8.self)
      #expect(out.contains("one\r\ntwo\r\n"))
      #expect(out.contains("Script started on Tue Nov 14 22:13:20 2023\n"))
      #expect(out.contains("\nScript done on Tue Nov 14 22:13:23 2023\n"))
    }
  }

  @Test func quietPlayback() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", sampleRecording())
    try await run(withStdin: "", output: "one\r\ntwo\r\n", error: "", args: "-p", "-d", "-q", "rec", cd: FilePath(d.root))
  }

  @Test func playbackOfAFileFromAPipe() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: sampleRecording(), output: "one\r\ntwo\r\n", error: "", args: "-p", "-d", "-q", "/dev/stdin", cd: FilePath(d.root))
  }

  @Test func playbackKeepsTheTimeBetweenRecords() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", scriptStamp(0, 100, 0, "s") + scriptStamp(1, 100, 0, "o") + [65] + scriptStamp(1, 101, 500_000, "o") + [66])
    let start = ContinuousClock.now
    try await run(withStdin: "", output: "AB", args: "-p", "-q", "rec", cd: FilePath(d.root))
    #expect(ContinuousClock.now - start >= .milliseconds(1400))
  }

  @Test func timeStamps() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", sampleRecording())
    try await run(withStdin: "", args: "-T", "%H:%M:%S|", "-q", "rec", env: ["TZ": "UTC"], cd: FilePath(d.root)) { po in
      // shown when the second changes between outputs
      #expect(String(decoding: po.data, as: UTF8.self) == "22:13:20|one\r\n22:13:23|two\r\n")
    }
  }

  @Test func timeStampsWithTheDefaultFormat() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", sampleRecording())
    try await run(withStdin: "", output: "\n@ 1700000000 [2023-11-14 22:13:20]\none\r\n\n@ 1700000003 [2023-11-14 22:13:23]\ntwo\r\n", error: "", args: "-T", "plain", "-q", "rec", env: ["TZ": "UTC"], cd: FilePath(d.root))
  }

  @Test func recordsWithoutDataAreNotTimeStamped() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", scriptStamp(0, 1_700_000_000, 0, "o") + scriptStamp(2, 1_700_000_000, 0, "o") + Array("zz".utf8) + scriptStamp(2, 1_700_000_005, 0, "o") + Array("yy".utf8))
    try await run(withStdin: "", output: "[20]zz[25]yy", error: "", args: "-T", "[%S]", "-q", "rec", env: ["TZ": "UTC"], cd: FilePath(d.root))
  }

  @Test func recordingMadeOnAMachineOfTheOtherEndianness() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("rec", scriptStamp(3, 1_700_000_001, 5, "o", bigEndian: true) + Array("abc".utf8))
    try await run(withStdin: "", output: "abc", error: "", args: "-p", "-d", "rec", cd: FilePath(d.root))
  }

  @Test func playbackOfARecordedSession() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    try await run(withStdin: "", args: "-q", "-r", "rec", "sh", "-c", "echo one; echo two", cd: FilePath(d.root))
    try await run(withStdin: "", output: "\(Self.eof)one\r\ntwo\r\n", error: "", args: "-p", "-d", "-q", "rec", cd: FilePath(d.root))
  }

  @Test func emptyRecording() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("empty", [])
    try await run(withStdin: "", output: "", error: "", args: "-p", "empty", cd: FilePath(d.root))
  }

  @Test func invalidDirection() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("bad", scriptStamp(0, 1000, 0, "x"))
    try await run(withStdin: "", status: 1, output: "", error: "script: invalid direction\n", args: "-p", "bad", cd: FilePath(d.root))
  }

  @Test func lengthBeyondTheFile() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("bad", scriptStamp(100, 1000, 0, "o") + Array("short".utf8))
    try await run(withStdin: "", status: 1, output: "", error: "script: invalid stamp\n", args: "-p", "bad", cd: FilePath(d.root))
  }

  @Test(arguments: [[UInt8](Array("abc".utf8)), Array(scriptStamp(0, 1000, 0, "o").dropLast(5))])
  func truncatedHeader(_ content: [UInt8]) async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    d.write("bad", content)
    try await run(withStdin: "", status: 1, output: "", error: /script: reading playback header: .*\n/, args: "-p", "bad", cd: FilePath(d.root))
  }

  // MARK: on a terminal

  @Test func onATerminalTheSessionIsShownAndRecorded() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let (status, shown) = try runOnTerminal(["-q", "out", "sh", "-c", "stty size; exit 4"], in: d)
    #expect(status == 4)
    // the size of the terminal is the size of the one script makes
    #expect(String(decoding: shown, as: UTF8.self) == "30 100\r\n")
    #expect(d.text("out") == "30 100\r\n")
  }

  @Test func onATerminalInputIsPassedOnAndTheTerminalIsRestored() async throws {
    let d = ScriptDirectory()
    defer { d.remove() }
    let (status, shown) = try runOnTerminal(["out", "sh", "-c", "echo ready; read x; echo got:$x"], in: d, input: Array("typed\n".utf8), after: "ready")
    #expect(status == 0)
    let text = String(decoding: shown, as: UTF8.self)
    #expect(text.hasPrefix("Script started, output file is out\r\n"))
    #expect(text.contains("got:typed\r\n"))
    #expect(text.hasSuffix("Script done, output file is out\r\n"))
    let file = try #require(d.text("out"))
    #expect(file.contains("got:typed\r\n"))
    #expect(file.contains("Command exit status: 0"))
  }
}

extension ScriptDirectory {
  func exists(_ name: String) -> Bool { access(path(name), F_OK) == 0 }
}
