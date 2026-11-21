// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A sleeping process with a name of its own, so killall can be pointed at it without touching anything else.
///
/// killall matches the last component of the path a process was executed with, so the process is started through
/// a symbolic link to /bin/sleep that has the wanted name.
final class Probe {
  let name: String
  let directory: String
  let pid: pid_t

  init(name: String? = nil) {
    var template = Array("/tmp/killalltestXXXXXX".utf8CString)
    self.directory = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    let suffix = String(UInt32.random(in: 0...UInt32.max), radix: 16)
    self.name = name ?? "kat" + suffix
    let path = directory + "/" + self.name
    symlink("/bin/sleep", path)

    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }
    // the test runner may ignore or block signals, and the child would inherit that
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

    var argv: [UnsafeMutablePointer<CChar>?] = [strdup(path), strdup("300"), nil]
    defer { for a in argv { free(a) } }
    var p: pid_t = 0
    let rc = posix_spawn(&p, path, &actions, &attr, argv, environ)
    precondition(rc == 0 && p > 0, "could not start the test process: \(rc)")
    self.pid = p
  }

  var isRunning: Bool {
    var status: Int32 = 0
    return waitpid(pid, &status, WNOHANG) == 0
  }

  /// How the process ended (waits for it): the signal that killed it, or nil if it exited by itself.
  func terminationSignal() -> Int32? {
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return (status & 0x7f) != 0 ? status & 0x7f : nil
  }

  func stop() {
    kill(pid, SIGKILL)
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    unlink(directory + "/" + name)
    rmdir(directory)
  }
}

extension killallTest {

  static let noMatch = "No matching processes \(getuid() != 0 ? "belonging to you " : "")were found\n"

  static let signalList = """
    hup int quit ill trap abrt emt fpe kill bus segv sys pipe alrm term urg stop \n\
    tstp cont chld ttin ttou io xcpu xfsz vtalrm prof winch info usr1 usr2 \n
    """

  static let usageText = """
    usage: killall [-delmsqvz] [-help] [-I]
                   [-u user] [-t tty] [-c cmd] [-SIGNAL] [cmd]...
    At least one option or argument to specify processes must be given.

    """

  // MARK: listing and usage

  @Test func listsTheSignals() async throws {
    try await run(output: Self.signalList, args: "-l")
  }

  /// -l is handled while the options are read, so it wins over the operands that follow.
  @Test(arguments: [["-s", "-l"], ["-l", "name"], ["-l", "-s", "name"], ["-s", "-l", "name"], ["-d", "-l"]])
  func listStopsTheRun(_ args: [String]) async throws {
    try await run(output: Self.signalList, args: args)
  }

  @Test(arguments: [[], ["-s"], ["-q"], ["-d"], ["-v"], ["-z"], ["-I"], ["-m"], ["-e"], ["-9"], ["-HUP", "-s"],
                    ["-help"], ["-s", "-help"], ["-s", "name", "-help"], ["-15", "-help", "name"], ["-j", "1", "-s"]])
  func usageErrors(_ args: [String]) async throws {
    try await run(status: 1, error: Self.usageText, args: args)
  }

  @Test(arguments: [(["-s", "-sig", "name"], "i"), (["-sq", "-sTERM", "name"], "T"), (["-dsig", "name"], "i"),
                    (["-zsig", "name"], "i"), (["-sigx", "-d"], "i")])
  func unknownOptionLetters(_ args: [String], _ letter: String) async throws {
    try await run(status: 1, error: Regex<Substring>(verbatim: "illegal option -- \(letter)\n" + Self.usageText),
                  args: args)
  }

  @Test(arguments: ["-c", "-u", "-t"])
  func optionsThatNeedAnArgument(_ opt: String) async throws {
    try await run(status: 1, error: /option requires an argument -- . *\n.*usage: killall/, args: ["-s", opt])
  }

  // MARK: bad signals

  @Test(arguments: [("-x", "x"), ("-h", "h"), ("-L", "L"), ("-FOO", "FOO"), ("-SIGFOO", "FOO"), ("-SIG", ""),
                    ("-SIGSIGTERM", "SIGTERM"), ("-+1", "+1"), ("-.", "."), ("-_", "_"), ("-é", "é"),
                    ("-32", "32"), ("-300", "300"), ("-999999999999", "999999999999"), ("-12345678901234567890", "12345678901234567890")])
  func unknownSignals(_ arg: String, _ shown: String) async throws {
    try await run(status: 1, error: "killall: unknown signal \(shown); valid signals:\n" + Self.signalList,
                  args: [arg, "name"])
  }

  @Test(arguments: ["-1x", "-0x1", "-9z", "-1.5", "-12e1"])
  func illegalSignalNumbers(_ arg: String) async throws {
    try await run(status: 1, error: "killall: illegal signal number: \(arg.dropFirst())\n", args: [arg, "name"])
  }

  /// A bad signal is found before the options are read, wherever it is, but not past `--`.
  @Test func badSignalsAreFoundWhereverTheyAre() async throws {
    try await run(status: 1, error: /unknown signal x;/, args: ["-s", "name", "-x"])
    try await run(status: 1, error: /unknown signal x;/, args: ["-l", "-x"])
    try await run(status: 1, error: /unknown signal x;/, args: ["-x", "-l"])
    try await run(status: 1, error: /unknown signal x;/, args: ["-sTERM", "-x", "name"])
    try await run(status: 1, error: /^killall: usage|usage: killall/, args: ["-help", "-x"])
    try await run(status: 1, error: /unknown signal x;/, args: ["-x", "-help"])
  }

  @Test func theFirstBadSignalIsTheOneReported() async throws {
    try await run(status: 1, error: /illegal signal number: 1x/, args: ["-1x", "-FOO", "-s", "name"])
    try await run(status: 1, error: /unknown signal FOO;/, args: ["-FOO", "-1x", "-s", "name"])
  }

  // MARK: selecting by name

  @Test func printsWhatItWouldDo() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -term \(p.pid)\n", args: "-s", p.name)
    #expect(p.isRunning)
  }

  /// Every spelling of a signal: with and without SIG, in either case, or as a number.
  @Test(arguments: [("-HUP", "hup"), ("-hup", "hup"), ("-SIGHUP", "hup"), ("-sighup", "hup"), ("-SigHup", "hup"),
                    ("-1", "hup"), ("-KILL", "kill"), ("-9", "kill"), ("-INT", "int"), ("-2", "int"),
                    ("-USR1", "usr1"), ("-30", "usr1"), ("-INFO", "info"), ("-29", "info"), ("-0", "Signal 0"),
                    ("-00", "Signal 0"), ("-012", "sys"), ("-15", "term"), ("-TERM", "term"), ("-Term", "term"),
                    ("-4294967297", "hup")])
  func signalSpellings(_ spelling: String, _ named: String) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -\(named) \(p.pid)\n", args: "-s", spelling, p.name)
  }

  /// Names that begin with a letter that is also an option: the name is looked up first.
  @Test(arguments: [("-cont", "cont"), ("-CONT", "cont"), ("-chld", "chld"), ("-emt", "emt"), ("-io", "io"),
                    ("-ill", "ill"), ("-stop", "stop"), ("-sys", "sys"), ("-tstp", "tstp"), ("-ttin", "ttin"),
                    ("-urg", "urg"), ("-usr2", "usr2"), ("-vtalrm", "vtalrm"), ("-xcpu", "xcpu"), ("-IO", "io")])
  func signalNamesThatLookLikeOptions(_ spelling: String, _ named: String) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -\(named) \(p.pid)\n", args: "-s", spelling, p.name)
  }

  @Test(arguments: [["-s", "-HUP", "NAME"], ["-s", "NAME", "-HUP"], ["-HUP", "-s", "NAME"], ["-s", "-c", "-HUP", "NAME"],
                    ["-s", "-c", "NAME", "-HUP"]])
  func theSignalCanBeAnywhere(_ template: [String]) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -hup \(p.pid)\n", args: template.map { $0 == "NAME" ? p.name : $0 })
  }

  @Test func theLastSignalWins() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -int \(p.pid)\n", args: "-s", "-HUP", "-INT", p.name)
    try await run(output: "kill -hup \(p.pid)\n", args: "-s", "-INT", "-1", p.name)
    try await run(output: "kill -int \(p.pid)\n", args: "-INT", "-s", p.name, "-HUP", "-2")
  }

  @Test func doubleDashEndsTheSignals() async throws {
    let p = Probe()
    defer { p.stop() }
    // after "--" everything is a process name: "-9" is one, and it matches nothing
    try await run(status: 1, error: Self.noMatch, args: "-s", "--", "-9")
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "--", p.name, "-9")
    try await run(output: "kill -kill \(p.pid)\n", args: "-s", "-9", "--", p.name)
    try await run(status: 1, error: Self.noMatch, args: "-s", "-c", p.name, "--", "-9")
  }

  @Test func aLoneDashIsAName() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-", p.name)
  }

  @Test func namesAreCaseSensitiveAndExact() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(status: 1, error: Self.noMatch, args: "-s", p.name.uppercased())
    try await run(status: 1, error: Self.noMatch, args: "-s", String(p.name.dropLast()))
    try await run(status: 1, error: Self.noMatch, args: "-s", p.name + "x")
    try await run(status: 1, error: Self.noMatch, args: "-s", "")
  }

  @Test func anyOperandMayMatch() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "nosuchprocess_zz", p.name)
    try await run(output: "kill -term \(p.pid)\n", args: "-s", p.name, "nosuchprocess_zz")
  }

  @Test func everyProcessWithTheNameIsSelected() async throws {
    let name = "katmulti" + String(UInt32.random(in: 0...UInt32.max), radix: 16)
    let a = Probe(name: name), b = Probe(name: name)
    defer { a.stop(); b.stop() }
    try await run(args: "-s", name) { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n").sorted()
      #expect(lines == ["kill -term \(a.pid)", "kill -term \(b.pid)"].sorted())
    }
  }

  @Test func theCommandOptionTakesTheName() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-c", p.name)
    try await run(status: 1, error: Self.noMatch, args: "-s", "-c", String(p.name.dropLast()))
    // the last -c is the one that counts
    try await run(status: 1, error: Self.noMatch, args: "-s", "-c", p.name, "-c", "nosuchprocess_zz")
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-c", "nosuchprocess_zz", "-c", p.name)
  }

  /// With -c and operands both, the process has to satisfy both.
  @Test func theCommandOptionAndOperandsBothApply() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-c", p.name, p.name)
    try await run(status: 1, error: Self.noMatch, args: "-s", "-c", p.name, "nosuchprocess_zz")
    try await run(status: 1, error: Self.noMatch, args: "-s", "-c", "nosuchprocess_zz", p.name)
  }

  /// The kernel only keeps the first 16 characters of a command name, and -c compares just that much.
  @Test func theCommandOptionComparesSixteenCharacters() async throws {
    let p = Probe(name: "katlong" + String(UInt32.random(in: 0...UInt32.max), radix: 16) + "_name_that_is_long")
    defer { p.stop() }
    let sixteen = String(p.name.prefix(16))
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-c", p.name)
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-c", sixteen)
    try await run(output: "kill -term \(p.pid)\n", args: "-s", "-c", sixteen + "xyz")
    try await run(status: 1, error: Self.noMatch, args: "-s", "-c", String(p.name.prefix(15)))
    // but an operand has to be the whole name
    try await run(status: 1, error: Self.noMatch, args: "-s", sixteen)
    try await run(output: "kill -term \(p.pid)\n", args: "-s", p.name)
  }

  // MARK: regular expressions

  @Test func regularExpressions() async throws {
    let p = Probe()
    defer { p.stop() }
    let line = "kill -term \(p.pid)\n"
    try await run(output: line, args: "-s", "-m", p.name)
    try await run(output: line, args: "-s", "-m", "^" + p.name + "$")
    // the other tests' processes are all called kat..., so anchor on all but the last character
    try await run(output: line, args: "-s", "-m", "^" + p.name.dropLast())
    try await run(output: line, args: "-s", "-m", String(p.name.dropFirst(2)) + "$")
    try await run(output: line, args: "-s", "-m", "^k[a]t" + p.name.dropFirst(3).dropLast() + ".+")
    try await run(output: line, args: "-s", "-m", "(kat)\(p.name.dropFirst(3))")
    try await run(output: line, args: "-s", "-m", "nosuchprocess_zz|" + p.name)
    try await run(output: line, args: "-s", "-m", "-c", "^" + p.name.dropLast(), p.name)
    try await run(output: line, args: "-s", "-m", "-c", p.name, "^" + p.name.dropLast())
    try await run(status: 1, error: Self.noMatch, args: "-s", "-m", "^" + String(p.name.dropFirst()))
    try await run(status: 1, error: Self.noMatch, args: "-s", "-m", "-c", "^" + p.name.dropLast(), "nosuchprocess_zz")
    try await run(status: 1, error: Self.noMatch, args: "-s", "-m", "^" + p.name.uppercased())
    try await run(status: 1, error: Self.noMatch, args: "-s", "-m", "-c", "nosuchprocess_zz", p.name)
  }

  /// A regular expression can match more than the process in question; the name must be matched against the
  /// name, not the path.
  @Test func regularExpressionsSeeOnlyTheName() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(status: 1, error: Self.noMatch, args: "-s", "-m", "^/tmp")
    try await run(status: 1, error: Self.noMatch, args: "-s", "-m", "^" + p.directory)
  }

  /// A pattern that doesn't compile is reported once, and from then on patterns are compared as plain names.
  @Test func illegalRegularExpressions() async throws {
    let p = Probe()
    defer { p.stop() }
    let line = "kill -term \(p.pid)\n"
    try await run(status: 1, error: "killall: (: illegal regexp\n" + Self.noMatch, args: "-s", "-m", "(")
    try await run(status: 1, error: "killall: *: illegal regexp\n" + Self.noMatch, args: "-s", "-m", "*")
    try await run(status: 1, error: "killall: : illegal regexp\n" + Self.noMatch, args: "-s", "-m", "")
    try await run(output: line, error: "killall: (: illegal regexp\n", args: "-s", "-m", "(", p.name)
    // a -c that doesn't compile is then compared as a plain name, which no process has
    try await run(status: 1, error: "killall: (: illegal regexp\n" + Self.noMatch, args: "-s", "-m", "-c", "(", p.name)
    try await run(output: line, error: "killall: a(: illegal regexp\n", args: "-s", "-m", "a(", p.name, "(b")
    // the process that matches is found before the bad pattern is looked at
    try await run(output: line, args: "-s", "-m", p.name, "(")
  }

  // MARK: signalling for real

  @Test(arguments: [([String](), SIGTERM), (["-TERM"], SIGTERM), (["-15"], SIGTERM), (["-KILL"], SIGKILL),
                    (["-9"], SIGKILL), (["-HUP"], SIGHUP), (["-1"], SIGHUP), (["-INT"], SIGINT), (["-USR1"], SIGUSR1),
                    (["-sigusr2"], SIGUSR2), (["-QUIT"], SIGQUIT), (["-ALRM"], SIGALRM)])
  func signalsAreDelivered(_ opts: [String], _ expected: Int32) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(args: opts + [p.name])
    #expect(p.terminationSignal() == expected)
  }

  @Test func signalZeroOnlyChecks() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(args: "-0", p.name)
    #expect(p.isRunning)
  }

  @Test(arguments: ["-v", "-d"])
  func verboseAndDebugOutput(_ flag: String) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(args: flag, "-s", p.name) { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n").map(String.init)
      #expect(lines.last == "kill -term \(p.pid)")
      #expect(po.error.isEmpty)
    }
    #expect(p.isRunning)
  }

  @Test func verboseKills() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(output: "kill -kill \(p.pid)\n", args: "-v", "-9", p.name)
    #expect(p.terminationSignal() == SIGKILL)
  }

  @Test func debugShowsTheDetailsAndSendsNothing() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(status: 0, args: "-d", p.name) { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n").map(String.init)
      var rest = lines[...]
      if getuid() != 0 {
        #expect(rest.first == "uid:\(getuid())")
        rest = rest.dropFirst()
      }
      #expect(rest.first?.wholeMatch(of: /nprocs \d+/) != nil)
      rest = rest.dropFirst()
      #expect(rest.first?.wholeMatch(of: Regex<Substring>(verbatim: "sig:15, cmd:\(p.name), pid:\(p.pid), dev:0x[0-9a-f]+")) != nil || rest.first?.hasPrefix("sig:15, cmd:\(p.name), pid:\(p.pid), dev:0x") == true)
      #expect(rest.count == 1)
    }
    #expect(p.isRunning)
  }

  @Test func noMatchMessageAndStatus() async throws {
    try await run(status: 1, error: Self.noMatch, args: "nosuchprocess_zz")
    try await run(status: 1, error: "", args: "-q", "nosuchprocess_zz")
    try await run(status: 1, error: "", args: "-q", "-s", "-HUP", "nosuchprocess_zz")
  }

  @Test func debugAlsoReportsNoMatch() async throws {
    try await run(status: 1, error: Self.noMatch, args: "-d", "nosuchprocess_zz") { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n").map(String.init)
      #expect(lines.last?.hasPrefix("nprocs ") == true)
    }
  }

  // MARK: confirmation

  @Test(arguments: ["y\n", "Y\n", "yes\n", "yellow\n", "Yes please\n"])
  func confirmationAccepted(_ answer: String) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(withStdin: answer, output: "Send signal 15 to \(p.name) (pid \(p.pid))? kill -term \(p.pid)\n",
                  args: "-I", "-s", p.name)
  }

  @Test(arguments: ["n\n", "\n", "x\n", "no\n", "N\n", " y\n", ""])
  func confirmationRefused(_ answer: String) async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(withStdin: answer, status: 1, output: "Send signal 15 to \(p.name) (pid \(p.pid))? ",
                  error: Self.noMatch, args: "-I", "-s", p.name)
    #expect(p.isRunning)
  }

  @Test func confirmationKills() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(withStdin: "y\n", output: "Send signal 9 to \(p.name) (pid \(p.pid))? ", args: "-I", "-9", p.name)
    #expect(p.terminationSignal() == SIGKILL)
  }

  // MARK: user and tty

  @Test func theUserCanBeANameOrANumber() async throws {
    let p = Probe()
    defer { p.stop() }
    let line = "kill -term \(p.pid)\n"
    let me = String(cString: getpwuid(getuid()).pointee.pw_name)
    try await run(output: line, args: "-s", "-u", me, p.name)
    try await run(output: line, args: "-s", "-u", String(getuid()), p.name)
    try await run(output: line, args: "-s", "-u", "0\(getuid())", p.name)
    try await run(output: line, args: "-s", "-u", "+\(getuid())", p.name)
    try await run(output: line, args: "-s", "-u", " \(getuid())", p.name)
    try await run(output: line, args: "-s", "-e", "-u", me, p.name)
    try await run(output: line, args: "-s", "-u", me, "-c", p.name)
  }

  @Test func someoneElsesProcessesAreNotSelected() async throws {
    let p = Probe()
    defer { p.stop() }
    // nobody else's process is called that, and no process is owned by this uid
    try await run(status: 1, error: Self.noMatch, args: "-s", "-u", "99999", p.name)
    try await run(status: 1, error: Self.noMatch, args: "-s", "-u", "daemon", p.name)
  }

  @Test(arguments: ["", "nosuchuser_zz", "501abc", "0x1f5", "1 2"])
  func unknownUsers(_ user: String) async throws {
    try await run(status: 1, error: "killall: user \(user) does not exist\n", args: "-s", "-u", user, "name")
  }

  @Test func debugShowsTheNamedUsersId() async throws {
    let me = String(cString: getpwuid(getuid()).pointee.pw_name)
    try await run(status: 1, error: Self.noMatch, args: "-d", "-u", me, "nosuchprocess_zz") { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n")
      #expect(lines.first == "uid:\(Int32(bitPattern: getuid()))")
    }
    // a number is not looked up, so there is nothing to show
    try await run(status: 1, error: Self.noMatch, args: "-d", "-u", String(getuid()), "nosuchprocess_zz") { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n")
      #expect(lines.first?.hasPrefix("nprocs ") == true)
    }
  }

  @Test func unknownTerminals() async throws {
    try await run(status: 1, error: "killall: stat(/dev/ttynosuchtty_zz): No such file or directory\n",
                  args: "-s", "-t", "nosuchtty_zz", "name")
    try await run(status: 1, error: "killall: stat(/dev/ttynosuchtty_zz): No such file or directory\n",
                  args: "-s", "-t", "ttynosuchtty_zz", "name")
    try await run(status: 1, error: "killall: stat(/dev/nosuchtty_zz): No such file or directory\n",
                  args: "-s", "-t", "/dev/nosuchtty_zz", "name")
    try await run(status: 1, error: "killall: stat(/dev/ttyconsole): No such file or directory\n",
                  args: "-s", "-t", "console", "name")
  }

  @Test func terminalThatIsNotACharacterDevice() async throws {
    try await run(status: 1, error: "killall: /dev/fd: not a character device\n", args: "-s", "-t", "/dev/fd", "name")
  }

  @Test func debugShowsTheTerminalDevice() async throws {
    try await run(status: 1, error: Self.noMatch, args: "-d", "-t", "/dev/null", "nosuchprocess_zz") { po in
      let lines = try po.string(encoded: .utf8).split(separator: "\n").map(String.init)
      #expect(lines.first?.wholeMatch(of: /ttydev:0x[0-9a-f]+/) != nil)
    }
  }

  /// The probes have no controlling terminal, so asking for those on a terminal finds nothing.
  @Test func terminalSelection() async throws {
    let p = Probe()
    defer { p.stop() }
    try await run(status: 1, error: Self.noMatch, args: "-s", "-t", "/dev/null", p.name)
    try await run(status: 1, error: Self.noMatch, args: "-s", "-t", "/dev/tty", p.name)
    try await run(status: 1, error: Self.noMatch, args: "-s", "-t", "/dev/null", "-m", ".")
  }
}
