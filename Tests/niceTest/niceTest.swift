// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Serialized: `run` changes PATH for the whole process, and a test that is running at the same time can then find
/// that nice's own lookup of the utility fails.
@Suite("nice tests", .serialized) final class niceTest : ShellTest {
  let cmd = "nice"
  let suiteBundle = "shell_cmds_niceTest"

  static let usageText = "usage: nice [-n increment] utility [argument ...]\n"

  /// What the command run by nice reports as its own nice value (ps pads it with spaces).
  static let showNice = ["sh", "-c", "ps -o nice= -p $$"]

  /// The nice value that this process has, which is what the commands we start begin with.
  static var baseline : Int {
    errno = 0
    return Int(getpriority(PRIO_PROCESS, 0))
  }

  /// The nice value after an increment: it is kept in the range -20...20, and only the super-user can lower it.
  static func resulting(_ increment: Int) -> Int {
    let wanted = min(max(baseline + increment, -20), 20)
    return getuid() == 0 || increment >= 0 ? wanted : baseline
  }

  /// Runs `args` and checks the nice value the command reports.
  func expectNice(_ expected: Int, _ args: [String], warning: String = "") async throws {
    try await run(error: warning, args: args + Self.showNice) { po in
      let reported = try po.string(encoded: .utf8).trimmingPrefix(while: { $0 == " " }).dropLast()
      #expect(Int(reported) == expected, Comment("reported '\(reported)'"))
    }
  }

  // MARK: the increment

  @Test func defaultIncrementIsTen() async throws {
    try await expectNice(Self.resulting(10), [])
  }

  @Test(arguments: [0, 1, 5, 9, 19, 20, 21, 40, 100, 2147483647])
  func positiveIncrements(_ n: Int) async throws {
    try await expectNice(Self.resulting(n), ["-n", String(n)])
  }

  @Test(arguments: [-1, -5, -20, -40, -2147483648])
  func negativeIncrementsNeedPrivilege(_ n: Int) async throws {
    let warning = getuid() == 0 ? "" : "nice: setpriority: Permission denied\n"
    try await expectNice(Self.resulting(n), ["-n", String(n)], warning: warning)
  }

  @Test(arguments: [["-n5"], ["-n+5"], ["-n", "5"], ["-n", "05"], ["-n", "1", "-n", "5"]])
  func incrementForms(_ args: [String]) async throws {
    try await expectNice(Self.resulting(5), args)
  }

  @Test func leadingWhiteSpaceAndSignAreAccepted() async throws {
    try await expectNice(Self.resulting(5), ["-n", " 5"])
    try await expectNice(Self.resulting(5), ["-n", "+5"])
    try await expectNice(Self.resulting(8), ["-n", "08"])
  }

  /// The obsolescent -number: the increment follows the minus sign.
  @Test(arguments: [("-5", 5), ("-0", 0), ("-00", 0), ("-19", 19), ("-100", 100)])
  func obsoleteSyntax(_ arg: String, _ n: Int) async throws {
    try await expectNice(Self.resulting(n), [arg])
  }

  /// ... and --number is a negative increment.
  @Test func obsoleteNegativeSyntax() async throws {
    let warning = getuid() == 0 ? "" : "nice: setpriority: Permission denied\n"
    try await expectNice(Self.resulting(-5), ["--5"], warning: warning)
  }

  @Test func theLastIncrementWins() async throws {
    try await expectNice(Self.resulting(4), ["-n", "3", "-n", "4"])
    try await expectNice(Self.resulting(3), ["-5", "-n", "3"])
    try await expectNice(Self.resulting(4), ["-n", "1", "-n", "4"])
  }

  @Test func incrementsAddUpAcrossNiceCommands() async throws {
    // each is relative to the value it starts from
    try await expectNice(Self.resulting(10), ["-n", "5", "nice", "-n", "5"])
    try await expectNice(Self.resulting(25), ["-n", "19", "nice", "-n", "5"])
  }

  @Test func doubleDashEndsOptions() async throws {
    try await expectNice(Self.resulting(10), ["--"])
    try await expectNice(Self.resulting(5), ["-n", "5", "--"])
  }

  // MARK: bad increments

  @Test(arguments: ["1x", "abc", "", "0x5", "5 ", "1.5", "99999999999", "-2147483649", "2147483648", "+", "-", "--", " "])
  func invalidIncrements(_ n: String) async throws {
    try await run(status: 1, error: "nice: \(n): invalid nice value\n", args: "-n", n, "echo", "hi")
  }

  @Test(arguments: [("-5x", "5x"), ("--x", "-x"), ("-1.5", "1.5"), ("-99999999999", "99999999999"), ("--1x", "-1x")])
  func invalidObsoleteIncrements(_ arg: String, _ shown: String) async throws {
    try await run(status: 1, error: "nice: \(shown): invalid nice value\n", args: arg, "echo", "hi")
  }

  // MARK: usage

  @Test(arguments: [[], ["-n", "5"], ["-5"], ["--5"], ["-n", "5", "--"], ["--"]])
  func missingUtility(_ args: [String]) async throws {
    try await run(status: 1, error: Self.usageText, args: args)
  }

  @Test(arguments: [("-x", "illegal option -- x"), ("-+5", "illegal option -- +"),                     ("-h", "illegal option -- h"), ("-?", "illegal option -- ?")])
  func unknownOptions(_ opt: String, _ message: String) async throws {
    try await run(status: 1, error: "nice: \(message)\n" + Self.usageText, args: opt, "echo", "hi")
  }

  @Test func incrementNeedsAnArgument() async throws {
    try await run(status: 1, error: "nice: option requires an argument -- n\n" + Self.usageText, args: "-n")
  }

  @Test func optionsAfterTheUtilityBelongToIt() async throws {
    // echo takes the -n: it is not nice's
    try await run(output: "5", args: "echo", "-n", "5")
    try await run(output: "a -x\n", args: "echo", "a", "-x")
  }

  // MARK: the utility

  @Test func argumentsAreUnchanged() async throws {
    try await run(output: "a 2 b c d\n", args: "sh", "-c", "echo $0 $# \"$@\"", "a", "b", "c d")
    try await run(output: "a b c d\n", args: "-n", "3", "echo", "a", "b", "c d")
    try await run(output: "<>\n", args: "sh", "-c", "echo \"<$1>\"", "x", "")
  }

  @Test func theUtilityIsFoundOnThePathOrByName() async throws {
    try await run(output: "/bin/sh\n", args: "-n", "3", "/bin/sh", "-c", "echo $0")
    try await run(output: "yes\n", args: "echo", "yes")
  }

  @Test func standardStreamsArePassedThrough() async throws {
    try await run(withStdin: "hello\n", output: "hello\n", args: "cat")
    try await run(output: "out\n", error: "err\n", args: "sh", "-c", "echo err >&2; echo out")
  }

  @Test(arguments: [0, 1, 2, 7, 64, 126, 127, 255])
  func exitStatusIsTheUtilitys(_ code: Int) async throws {
    try await run(status: code, args: "sh", "-c", "exit \(code)")
    try await run(status: code, args: "-n", "5", "sh", "-c", "exit \(code)")
  }

  @Test func utilityKilledBySignal() async throws {
    try await run(status: 128 + Int(SIGKILL), args: "sh", "-c", "kill -9 $$")
  }

  @Test(arguments: [("nosuchcmd_zz", 127, "No such file or directory"), ("/nonexistent/cmd", 127, "No such file or directory"),
                    ("/etc/passwd", 126, "Permission denied"), ("/tmp", 126, "Permission denied"),
                    ("-", 127, "No such file or directory"), ("", 127, "No such file or directory")])
  func utilityThatCannotBeRun(_ command: String, _ status: Int, _ why: String) async throws {
    try await run(status: status, error: "nice: \(command): \(why)\n", args: command)
    try await run(status: status, error: "nice: \(command): \(why)\n", args: "-n", "5", command)
  }

  @Test func dashDashThenOptionLikeUtility() async throws {
    try await run(status: 127, error: "nice: -n: No such file or directory\n", args: "--", "-n", "5", "echo")
    try await run(status: 127, error: "nice: --: No such file or directory\n", args: "--", "--")
  }
}
