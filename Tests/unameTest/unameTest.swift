// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// What the system says about itself, from the uname call (which is what the command is supposed to agree with).
struct SystemNames {
  var sysname = "", nodename = "", release = "", version = "", machine = ""

  init() {
    var u = utsname()
    uname(&u)
    func text<T>(_ field: T) -> String {
      withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    sysname = text(u.sysname)
    nodename = text(u.nodename)
    release = text(u.release)
    version = text(u.version)
    machine = text(u.machine)
  }

  /// The version, with the tabs and the line ends shown as spaces.
  var shownVersion: String {
    String(decoding: Array(version.utf8).map { $0 == 0x0a || $0 == 0x09 ? 0x20 : $0 }, as: UTF8.self)
  }

  /// The type of the processor.
  var processor: String {
#if arch(arm64) || arch(arm)
    "arm"
#elseif arch(x86_64) || arch(i386)
    "i386"
#else
    "unknown"
#endif
  }
}

@Suite("uname") final class unameTest : ShellTest {
  let cmd = "uname"
  let suiteBundle = "shell_cmds_unameTest"

  let names = SystemNames()
  static let usageText = "usage: uname [-amnoprsv]\n"

  // MARK: usage

  @Test(arguments: ["-x", "-z", "-i", "-b", "-K", "-U", "-?"])
  func unknownOption(_ opt: String) async throws {
    try await run(status: 1, output: "", error: "uname: illegal option -- \(opt.dropFirst())\n" + Self.usageText, args: opt)
  }

  @Test(arguments: [["a"], ["-s", "a"], ["-a", "x", "y"]])
  func operandsAreNotAllowed(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Self.usageText, args: args)
  }

  // MARK: what is shown

  @Test func systemNameIsTheDefault() async throws {
    try await run(output: "\(names.sysname)\n", error: "", args: [String]())
  }

  @Test(arguments: ["-s", "-o", "-so", "-ss"])
  func systemName(_ opt: String) async throws {
    try await run(output: "\(names.sysname)\n", error: "", args: opt)
  }

  @Test func nodeName() async throws {
    try await run(output: "\(names.nodename)\n", error: "", args: "-n")
  }

  @Test func release() async throws {
    try await run(output: "\(names.release)\n", error: "", args: "-r")
  }

  @Test func version() async throws {
    try await run(output: "\(names.shownVersion)\n", error: "", args: "-v")
  }

  @Test func machine() async throws {
    try await run(output: "\(names.machine)\n", error: "", args: "-m")
  }

  @Test func processor() async throws {
    try await run(output: "\(names.processor)\n", error: "", args: "-p")
  }

  /// Always in the same order, whatever the order of the options.
  @Test(arguments: [["-n", "-s"], ["-sn"], ["-ns"], ["-s", "-n", "-s"]])
  func orderIsFixed(_ args: [String]) async throws {
    try await run(output: "\(names.sysname) \(names.nodename)\n", error: "", args: args)
  }

  @Test func everythingInItsOrder() async throws {
    try await run(output: "\(names.sysname) \(names.nodename) \(names.release) \(names.shownVersion) \(names.machine) \(names.processor)\n",
                  error: "", args: "-v", "-p", "-m", "-r", "-n", "-s")
  }

  /// "All" doesn't have the processor type, which is not part of the behavior this system has.
  @Test(arguments: [["-a"], ["-a", "-a"], ["-a", "-s"]])
  func all(_ args: [String]) async throws {
    try await run(output: "\(names.sysname) \(names.nodename) \(names.release) \(names.shownVersion) \(names.machine)\n", error: "", args: args)
  }

  @Test func allAndProcessor() async throws {
    try await run(output: "\(names.sysname) \(names.nodename) \(names.release) \(names.shownVersion) \(names.machine) \(names.processor)\n",
                  error: "", args: "-a", "-p")
    try await run(output: "\(names.sysname) \(names.nodename) \(names.release) \(names.shownVersion) \(names.machine) \(names.processor)\n",
                  error: "", args: "-p", "-a")
  }

  @Test func doubleDash() async throws {
    try await run(output: "\(names.nodename)\n", error: "", args: "-n", "--")
    try await run(status: 1, output: "", error: Self.usageText, args: "--", "-s")
  }

  // MARK: overriding

  @Test(arguments: [("-s", "UNAME_s"), ("-s", "UNAME_SYSNAME"), ("-n", "UNAME_n"), ("-n", "UNAME_NODENAME"), ("-r", "UNAME_r"),
                    ("-r", "UNAME_RELEASE"), ("-v", "UNAME_v"), ("-v", "UNAME_VERSION"), ("-m", "UNAME_m"), ("-m", "UNAME_MACHINE"),
                    ("-p", "UNAME_p"), ("-o", "UNAME_s")])
  func overriddenByTheEnvironment(_ opt: String, _ variable: String) async throws {
    try await run(output: "overridden\n", error: "", args: opt, env: [variable: "overridden"])
  }

  @Test func theVariableOfThisSystemWins() async throws {
    try await run(output: "mine\n", error: "", args: "-s", env: ["UNAME_SYSNAME": "mine", "UNAME_s": "other"])
  }

  @Test func overridesAreShownInTheOrder() async throws {
    try await run(output: "S N R V M P\n", error: "", args: "-a", "-p", env: ["UNAME_s": "S", "UNAME_n": "N", "UNAME_r": "R", "UNAME_v": "V", "UNAME_m": "M", "UNAME_p": "P"])
  }

  /// Only the one asked for is overridden.
  @Test func overridesOnlyWhatIsShown() async throws {
    try await run(output: "\(names.nodename)\n", error: "", args: "-n", env: ["UNAME_s": "S"])
  }

  /// An override is shown as it is: the tabs and line ends are only taken out of what the system says.
  @Test func overrideIsNotChanged() async throws {
    try await run(output: "a\tb\nc\n", error: "", args: "-v", env: ["UNAME_VERSION": "a\tb\nc"])
  }

  @Test func emptyOverride() async throws {
    try await run(output: "\n", error: "", args: "-s", env: ["UNAME_SYSNAME": ""])
    try await run(output: " \(names.nodename)\n", error: "", args: "-sn", env: ["UNAME_s": ""])
  }

  @Test(arguments: ["UNAME_i", "UNAME_o", "UNAME_x", "UNAME_b", "UNAME_K", "UNAME_U"])
  func otherVariablesAreNotUsed(_ variable: String) async throws {
    try await run(output: "\(names.sysname)\n", error: "", args: [String](), env: [variable: "ignored"])
  }
}
