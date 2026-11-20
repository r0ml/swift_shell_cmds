
// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting

@Suite final class getoptTest : ShellTest {
  let cmd = "getopt"
  let suiteBundle = "shell_cmds_getoptTest"

  /// (arguments, expected stdout, expected exit status), recorded from the system getopt
  static let systemCases : [([String], String, Int)] = [
    (["abo:", "-a", "-b", "-o", "x", "y"], " -a -b -o x -- y\n", 0),
    (["abo:", "-ab", "-ofoo", "z"], " -a -b -o foo -- z\n", 0),
    (["abo:", "--", "-a"], " -- -a\n", 0),
    (["abo:", "-x"], " --\n", 1),
    (["abo:", "-o"], " --\n", 1),
    (["ab:", "-a", "x", "-b", "y"], " -a -- x -b y\n", 0),
    (["abo:"], " --\n", 0),
    (["ab"], " --\n", 0),
    (["ab", "-x", "-a"], " -a --\n", 1),
    (["ab", "-a", "-x", "-b", "y"], " -a -b -- y\n", 1),
    (["ab:", "-b"], " --\n", 1),
    (["ab:", "-a", "-b"], " -a --\n", 1),
    (["ab:", "-b", ""], " -b  --\n", 0),
    (["ab:", "-b", "", "y"], " -b  -- y\n", 0),
    (["ab:", "-b foo", "z"], " -b  foo -- z\n", 0),
    (["ab:", "-bfoo"], " -b foo --\n", 0),
    (["ab:", "-b", "-a"], " -b -a --\n", 0),
    (["ab", "-ab"], " -a -b --\n", 0),
    (["ab", "-ba", "-a"], " -b -a -a --\n", 0),
    (["a", "-a b"], " -a --\n", 1),
    (["ab", "-"], " -- -\n", 0),
    (["ab", "-", "a"], " -- - a\n", 0),
    (["ab", "--"], " --\n", 0),
    (["ab", "--", "--", "x"], " -- -- x\n", 0),
    (["ab", "x", "-a"], " -- x -a\n", 0),
    (["ab", "-a", "--", "-b", "-a"], " -a -- -b -a\n", 0),
    (["", "-a"], " --\n", 1),
    (["", "x"], " -- x\n", 0),
    ([":", "-a"], " --\n", 1),
    ([":a", "-a", "-b"], " -a --\n", 1),
    ([":a:", "-a"], " -: --\n", 0),
    ([":a:", "-b"], " --\n", 1),
    (["a:", "-a", "--"], " -a -- --\n", 0),
    (["a b", "-a"], " -a --\n", 0),
    (["a-", "-a"], " -a --\n", 0),
    (["a:b:c", "-aX", "-b", "Y", "-c"], " -a X -b Y -c --\n", 0),
    (["-a", "-a"], " -a --\n", 0),
    (["?a", "-a", "-?"], " -a --\n", 1),
    (["a:", "-a", " "], " -a   --\n", 0),
    (["a", "-a", "x y", "z"], " -a -- x y z\n", 0),
    (["a::", "-a", "x"], " -a -- x\n", 0),
    (["a::", "-afoo"], " -a foo --\n", 0),
    (["a::", "-afoo", "bar"], " -a foo -- bar\n", 0),
    (["ab::", "-b", "-a"], " -b -a --\n", 0),
    (["ab::", "-bfoo", "-a"], " -b foo -a --\n", 0),
    (["a::", "-a"], " -a --\n", 0),
    (["a:", "-a", ""], " -a  --\n", 0),
    (["abc", "-abc", "-c"], " -a -b -c -c --\n", 0),
    (["abc", "-abcx"], " -a -b -c --\n", 1),
    (["abc", "-xabc"], " -a -b -c --\n", 1),
    (["abc", "-a", "-b", "-c", "-d", "-e"], " -a -b -c --\n", 1),
    (["w:", "-wfoo", "-w", "bar", "baz"], " -w foo -w bar -- baz\n", 0),
    (["--", "-a"], " --\n", 1),
    (["--", "x"], " -- x\n", 0),
    (["-a"], " --\n", 0),
    (["a", "-a", "-a", "-a"], " -a -a -a --\n", 0),
    (["a:", "-a", "a", "-a", "b"], " -a a -a b --\n", 0),
    (["a:", "-aa", "-ab"], " -a a -a b --\n", 0),
    (["abcdefghijklmnopqrstuvwxyz", "-abcdefghijklmnopqrstuvwxyz"], " -a -b -c -d -e -f -g -h -i -j -k -l -m -n -o -p -q -r -s -t -u -v -w -x -y -z --\n", 0),
    (["a:", "--"], " --\n", 0),
    (["a:", "-a", "--", "b"], " -a -- -- b\n", 0),
    (["ab", "-b", "--", "-a", "--", "x"], " -b -- -a -- x\n", 0),
    (["ab", "-a", "-b", "x", "-a"], " -a -b -- x -a\n", 0),
    (["a", "-a", "its"], " -a -- its\n", 0),
    (["a:", "-a", "its"], " -a its --\n", 0),
    ([], " --\n", 0)
  ]

  @Test("getopt output matches the system getopt", arguments: systemCases)
  func matchesSystemGetopt(_ args: [String], _ expected: String, _ status: Int) async throws {
    try await run(status: status, output: expected, args: args)
  }

  @Test func exampleFromManualPage() async throws {
    try await run(output: " -a -b -o x -- y z\n", args: "abo:", "-a", "-b", "-o", "x", "y", "z")
  }

  @Test func optionsAreSplitAndOperandsFollowTheSeparator() async throws {
    try await run(output: " -a -b -o foo -- rest -a\n", args: "abo:", "-ab", "-ofoo", "rest", "-a")
  }

  @Test func unknownOptionIsReportedButParsingContinues() async throws {
    try await run(status: 1, output: " -a -b -- y\n", error: /illegal option -- x/, args: "ab", "-a", "-x", "-b", "y")
  }

  @Test func missingArgumentIsReported() async throws {
    try await run(status: 1, output: " -a --\n", error: /option requires an argument -- b/, args: "ab:", "-a", "-b")
  }
}
