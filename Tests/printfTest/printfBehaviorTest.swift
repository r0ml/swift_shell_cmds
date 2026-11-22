// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting

extension printfTest {

  static let usageText = "usage: printf format [arguments ...]\n"

  // MARK: usage

  @Test(arguments: [[String](), ["--"], ["-x"], ["--help"]])
  func usageErrors(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Regex<Substring>(verbatim: Self.usageText), args: args)
  }

  @Test func emptyFormat() async throws {
    try await run(output: "", args: "")
    try await run(output: "", args: "--", "")
  }

  // MARK: using the format again

  @Test func formatIsReusedWhileArgumentsRemain() async throws {
    try await run(output: "a b\nc \n", args: "%s %s\n", "a", "b", "c")
    try await run(output: "1\n2\n3\n", args: "%d\n", "1", "2", "3")
    try await run(output: "a1b2\n", args: "a%sb%s\n", "1", "2")
  }

  @Test func missingArgumentsAreEmptyOrZero() async throws {
    try await run(output: "0,0.000000,,\n", args: "%d,%f,%c,%s\n")
    try await run(output: "1 |\n", args: "%d %s|\n", "1")
  }

  /// A format with no conversions can't use the arguments that are left.
  @Test func argumentsThatNothingUses() async throws {
    try await run(status: 1, output: "x\n", error: "printf: missing format character\n", args: "x\n", "a", "b")
  }

  // MARK: conversions

  @Test(arguments: [("%5d|", "42", "   42|"), ("%-5d|", "42", "42   |"), ("%05d", "42", "00042"), ("%+d", "42", "+42"),
                    ("%x", "255", "ff"), ("%#X", "255", "0XFF"), ("%o", "8", "10"), ("%u", "-1", "18446744073709551615"),
                    ("%.3d", "5", "005"), ("%e", "1.5", "1.500000e+00"), ("%.2f", "3.14159", "3.14"), ("%g", "0.0001", "0.0001"),
                    ("%a", "1", "0x1p+0"), ("%10.3f|", "3.14159", "     3.142|"), ("%s", "text", "text"), ("%5.2s|", "abc", "   ab|"),
                    ("%c", "xyz", "x"), ("%%", "", "%")])
  func conversion(_ format: String, _ arg: String, _ expected: String) async throws {
    // (an empty arg stands for none: a format with no conversions can't use any)
    try await run(output: expected, args: arg.isEmpty ? [format] : [format, arg])
  }

  @Test(arguments: [("0x1f", "31"), ("010", "8"), ("-0x10", "-16"), ("+7", "7"), (" 5", "5"), ("'a", "97"), ("\"a", "97"), ("'é", "233"),
                    ("'日", "26085")])
  func integerArguments(_ arg: String, _ expected: String) async throws {
    try await run(output: expected + "\n", args: "%d\n", arg, env: ["LC_ALL": "en_US.UTF-8"])
  }

  @Test(arguments: [("abc", "expected numeric value"), ("", "expected numeric value"), ("1x", "not completely converted"),
                    ("1.5", "not completely converted"), ("09", "not completely converted"),
                    ("9223372036854775808", "Result too large")])
  func badIntegers(_ arg: String, _ why: String) async throws {
    // the conversion is done anyway: the exit status is what says something was wrong
    try await run(status: 1, error: "printf: \(arg): \(why)\n", args: "%d\n", arg) { po in
      #expect(!po.data.isEmpty)
    }
  }

  @Test(arguments: [("%q", "illegal format character q"), ("%", "missing format character"), ("%5", "missing format character"),
                    ("%Ld", "bad modifier L for %d"), ("%Lc", "bad modifier L for %c"), ("%n", "illegal format character n")])
  func badFormats(_ format: String, _ message: String) async throws {
    try await run(status: 1, error: "printf: \(message)\n", args: format, "1")
  }

  // MARK: width and precision from arguments

  @Test func starWidthAndPrecision() async throws {
    try await run(output: "   42|\n", args: "%*d|\n", "5", "42")
    try await run(output: "42   |\n", args: "%*d|\n", "-5", "42")
    try await run(output: "    3.14|\n", args: "%*.*f|\n", "8", "2", "3.14159")
    try await run(output: "00042\n", args: "%.*d\n", "5", "42")
  }

  @Test func badStarArgumentEndsTheRun() async throws {
    try await run(status: 1, output: "", error: "printf: abc: expected numeric value\n", args: "%*s|\n", "abc", "x")
    try await run(status: 1, output: "a", error: "printf: 5x: not completely converted\n", args: "a%*d|\n", "5x", "5")
  }

  // MARK: numbered arguments

  @Test func numberedArguments() async throws {
    try await run(output: "2 1\n", args: "%2$s %1$s\n", "1", "2")
    try await run(output: "1 1\n", args: "%1$s %1$s\n", "1")
    try await run(output: " 1\n", args: "%1$*2$d\n", "1", "2")
    try await run(output: "123\n", args: "%1$d%2$d%3$d\n", "1", "2", "3")
  }

  /// Each use of the format starts after the arguments the last one used, and the numbers count from there.
  @Test func numberedArgumentsWhenTheFormatIsReused() async throws {
    try await run(output: "1\n2\n3\n", args: "%1$d\n", "1", "2", "3")
    try await run(output: "2 1\n0 3\n", args: "%2$d %1$d\n", "1", "2", "3")
    try await run(output: "1 2\n3 0\n", args: "%1$d %d\n", "1", "2", "3")
  }

  @Test func argumentBeyondTheEnd() async throws {
    try await run(output: "\n", args: "%3$s\n", "255")
  }

  // MARK: escapes

  @Test(arguments: [("a\\nb", "a\nb"), ("\\t|", "\t|"), ("\\\\", "\\"), ("\\101", "A"), ("\\1010", "A0"), ("\\x41", "x41"),
                    ("\\q", "q"), ("\\'", "'"), ("\\\"", "\""), ("a\\", "a\\"), ("\\a\\b\\f\\v\\r", "\u{7}\u{8}\u{c}\u{b}\r"),
                    ("a\\cb", "acb"), ("%%\\045", "%%"), ("x\\0y", "x\u{0}y")])
  func formatEscapes(_ format: String, _ expected: String) async throws {
    try await run(output: expected, args: format)
  }

  @Test(arguments: [("a\\nb", "a\nb"), ("\\0101", "A"), ("\\101", "A"), ("\\\\", "\\"), ("x\\cy", "x"), ("\\q", "q"),
                    ("\\1012", "A2"), ("\\", "\\")])
  func percentBEscapes(_ arg: String, _ expected: String) async throws {
    // (\c stops everything, so the "|" only follows when it didn't)
    let stops = arg.contains("\\c")
    try await run(output: stops ? expected : expected + "|", args: "%b|", arg)
  }

  @Test func backslashCInPercentBEndsAllOutput() async throws {
    try await run(output: "abcdef\n", args: "abc%b%b", "def\n", "\\cghi")
    try await run(output: "a", args: "%b%s", "a\\c", "never")
  }

  @Test func aLoneNulFromPercentB() async throws {
    try await run(output: [UInt8]([0x78, 0x7c, 0x00, 0x7c]), args: "%s|%b|", "x", "\\0")
  }
}
