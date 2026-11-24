// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting

/// Results recorded from the system's seq, for the argument lists they were made with.
let seqRecordedResults: [([String], Int, String, String)] = [
    (["3"], 0, "1\n2\n3\n", ""),
    (["1", "3"], 0, "1\n2\n3\n", ""),
    (["3", "1"], 0, "3\n2\n1\n", ""),
    (["1", "2", "10"], 0, "1\n3\n5\n7\n9\n", ""),
    (["10", "-3", "1"], 0, "10\n7\n4\n1\n", ""),
    (["0.1", "0.1", "1"], 0, "0.1\n0.2\n0.3\n0.4\n0.5\n0.6\n0.7\n0.8\n0.9\n1\n", ""),
    (["-1", "-3"], 0, "-1\n-2\n-3\n", ""),
    (["-3", "-1"], 0, "-3\n-2\n-1\n", ""),
    (["-1", "1e-1", "2"], 0, "-1\n-0.9\n-0.8\n-0.7\n-0.6\n-0.5\n-0.4\n-0.3\n-0.2\n-0.1\n5.55112e-17\n0.1\n0.2\n0.3\n0.4\n0.5\n0.6\n0.7\n0.8\n0.9\n1\n1.1\n1.2\n1.3\n1.4\n1.5\n1.6\n1.7\n1.8\n1.9\n2\n", ""),
    (["-w", "8", "12"], 0, "08\n09\n10\n11\n12\n", ""),
    (["-w", "1", "0.5", "3"], 0, "1.0\n1.5\n2.0\n2.5\n3.0\n", ""),
    (["-ww", "1", "0.5", "3"], 0, " 1.0\n 1.5\n 2.0\n 2.5\n 3.0\n", ""),
    (["-w", "-5", "5"], 0, "-5\n-4\n-3\n-2\n-1\n00\n01\n02\n03\n04\n05\n", ""),
    (["-w", "-f", "%g", "3"], 0, "1\n2\n3\n", ""),
    (["-w", "1", "1e2"], 0, "001\n002\n003\n004\n005\n006\n007\n008\n009\n010\n011\n012\n013\n014\n015\n016\n017\n018\n019\n020\n021\n022\n023\n024\n025\n026\n027\n028\n029\n030\n031\n032\n033\n034\n035\n036\n037\n038\n039\n040\n041\n042\n043\n044\n045\n046\n047\n048\n049\n050\n051\n052\n053\n054\n055\n056\n057\n058\n059\n060\n061\n062\n063\n064\n065\n066\n067\n068\n069\n070\n071\n072\n073\n074\n075\n076\n077\n078\n079\n080\n081\n082\n083\n084\n085\n086\n087\n088\n089\n090\n091\n092\n093\n094\n095\n096\n097\n098\n099\n100\n", ""),
    (["-w", "1e-2", "1"], 0, "0.01\n", ""),
    (["-w", "0.001", "0.001", "0.003"], 0, "0.001\n0.002\n0.003\n", ""),
    (["-w", ".5", "2"], 0, "0.5\n1.5\n", ""),
    (["-w", "5.", "7"], 0, "5\n6\n7\n", ""),
    (["-w", "-.5", "1"], 0, "-0.5\n00.5\n", ""),
    (["--equal-width", "8", "11"], 0, "08\n09\n10\n11\n", ""),
    (["--eq", "8", "11"], 0, "08\n09\n10\n11\n", ""),
    (["-f", "%03.1f", "1", "3"], 0, "1.0\n2.0\n3.0\n", ""),
    (["-f", "x%gy", "2"], 0, "x1y\nx2y\n", ""),
    (["-f", "%e", "1", "3"], 0, "1.000000e+00\n2.000000e+00\n3.000000e+00\n", ""),
    (["-f", "%5.2f|", "1", "0.5", "3"], 0, " 1.00|\n 1.50|\n 2.00|\n 2.50|\n 3.00|\n", ""),
    (["-f", "%%%g", "2"], 0, "%1\n%2\n", ""),
    (["-f", "%10%", "2"], 1, "", "seq: invalid format string: `%10%'\n"),
    (["-f", "foo", "3"], 1, "", "seq: invalid format string: `foo'\n"),
    (["-f", "%d", "3"], 1, "", "seq: invalid format string: `%d'\n"),
    (["-f", "%g%g", "3"], 1, "", "seq: invalid format string: `%g%g'\n"),
    (["-f", "%lf", "3"], 1, "", "seq: invalid format string: `%lf'\n"),
    (["-f", "%'g", "3"], 0, "1\n2\n3\n", ""),
    (["-f", "a\\x25g", "2"], 1, "", "seq: invalid format string: `a\\x25g'\n"),
    (["-f", "\\045g", "2"], 1, "", "seq: invalid format string: `\\045g'\n"),
    (["-f", "%g\\n", "2"], 0, "1\n\n2\n\n", ""),
    (["-f", "%g\\q", "2"], 0, "1\\q\n2\\q\n", ""),
    (["-f", "%g\\", "2"], 0, "1\\\n2\\\n", ""),
    (["-f", "%g\\x", "2"], 0, "1\n2\n", ""),
    (["-f", "%g\\0x", "2"], 0, "1\n2\n", ""),
    (["-f", "%a", "2"], 0, "0x1p+0\n0x1p+1\n", ""),
    (["-f", "%A", "2"], 0, "0X1P+0\n0X1P+1\n", ""),
    (["-f", "%G", "2"], 0, "1\n2\n", ""),
    (["-f", "%E", "2"], 0, "1.000000E+00\n2.000000E+00\n", ""),
    (["-f", "%F", "2"], 0, "1.000000\n2.000000\n", ""),
    (["-f", "% g", "2"], 0, " 1\n 2\n", ""),
    (["-f", "%+g", "2"], 0, "+1\n+2\n", ""),
    (["-f", "%#g", "2"], 0, "1.00000\n2.00000\n", ""),
    (["-f", "%-5g|", "2"], 0, "1    |\n2    |\n", ""),
    (["-f", "%05g", "2"], 0, "00001\n00002\n", ""),
    (["-f", "%.g", "2"], 0, "1\n2\n", ""),
    (["-f", "%5.", "2"], 1, "", "seq: invalid format string: `%5.'\n"),
    (["-f", "%", "2"], 1, "", "seq: invalid format string: `%'\n"),
    (["-f", "%%", "2"], 1, "", "seq: invalid format string: `%%'\n"),
    (["-f", "", "2"], 1, "", "seq: invalid format string: `'\n"),
    (["-f", "%1$g", "2"], 1, "", "seq: invalid format string: `%1$g'\n"),
    (["--format=%g!", "2"], 0, "1!\n2!\n", ""),
    (["--format", "%g", "2"], 0, "1\n2\n", ""),
    (["-wf", "%g", "3"], 0, "1\n2\n3\n", ""),
    (["-wfx%g", "3"], 0, "x1\nx2\nx3\n", ""),
    (["-f", "%g", "-w", "3"], 0, "1\n2\n3\n", ""),
    (["-w", "-f", "%g", "3"], 0, "1\n2\n3\n", ""),
    (["-s", ",", "5"], 0, "1,2,3,4,5,", ""),
    (["-s", "\\t", "3"], 0, "1\t2\t3\t", ""),
    (["-s", "\\0", "3"], 0, "123", ""),
    (["-s", "\\x41", "3"], 0, "1A2A3A", ""),
    (["-s", "\\101", "3"], 0, "1A2A3A", ""),
    (["-s", "\\q", "3"], 0, "1\\q2\\q3\\q", ""),
    (["-s", "", "3"], 0, "123", ""),
    (["-s", "ab\\", "3"], 0, "1ab\\2ab\\3ab\\", ""),
    (["-s", "x", "-s", "y", "3"], 0, "1y2y3y", ""),
    (["-t", "END\\n", "3"], 0, "1\n2\n3\nEND\n", ""),
    (["-t", "", "3"], 0, "1\n2\n3\n", ""),
    (["-s", ":", "-t", "!", "4"], 0, "1:2:3:4:!", ""),
    (["--separator=-", "3"], 0, "1-2-3-", ""),
    (["--terminator", "T", "2"], 0, "1\n2\nT", ""),
    (["--term=z", "2"], 0, "1\n2\nz", ""),
    (["--sep", "x", "3"], 0, "1x2x3x", ""),
    (["-w", "-s", ",", "1", "3"], 0, "1,2,3,", ""),
    (["--help"], 1, "", "seq: unrecognized option `--help'\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["-h"], 1, "", "usage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["-x", "3"], 1, "", "seq: invalid option -- x\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["-xz", "3"], 1, "", "seq: invalid option -- x\nseq: invalid option -- z\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["--bogus", "3"], 1, "", "seq: unrecognized option `--bogus'\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["-f"], 1, "", "seq: option requires an argument -- f\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["-s"], 1, "", "seq: option requires an argument -- s\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    ([], 1, "", "usage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["1", "2", "3", "4"], 1, "", "usage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["abc"], 2, "", "seq: invalid floating point argument: abc\n"),
    (["1", "abc"], 2, "", "seq: invalid floating point argument: abc\n"),
    (["1e999"], 2, "", "seq: 1e999: Result too large\n"),
    (["-1e999", "1"], 2, "", "seq: -1e999: Result too large\n"),
    (["1e-400"], 2, "", "seq: 1e-400: Result too large\n"),
    (["1", "0", "5"], 1, "", "seq: zero increment\n"),
    (["5", "0", "1"], 1, "", "seq: zero decrement\n"),
    (["1", "-1", "5"], 1, "", "seq: needs positive increment\n"),
    (["5", "1", "1"], 1, "", "seq: needs negative decrement\n"),
    (["--", "3"], 0, "1\n2\n3\n", ""),
    (["--", "-3", "-1"], 0, "-3\n-2\n-1\n", ""),
    (["-", "3"], 2, "", "seq: invalid floating point argument: -\n"),
    (["", "3"], 0, "0\n1\n2\n3\n", ""),
    (["3", ""], 0, "3\n2\n1\n0\n", ""),
    (["1e2"], 0, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24\n25\n26\n27\n28\n29\n30\n31\n32\n33\n34\n35\n36\n37\n38\n39\n40\n41\n42\n43\n44\n45\n46\n47\n48\n49\n50\n51\n52\n53\n54\n55\n56\n57\n58\n59\n60\n61\n62\n63\n64\n65\n66\n67\n68\n69\n70\n71\n72\n73\n74\n75\n76\n77\n78\n79\n80\n81\n82\n83\n84\n85\n86\n87\n88\n89\n90\n91\n92\n93\n94\n95\n96\n97\n98\n99\n100\n", ""),
    (["1e0", "3"], 0, "1\n2\n3\n", ""),
    (["+1", "+3"], 0, "1\n2\n3\n", ""),
    (["0x10"], 0, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n", ""),
    (["0x1p3"], 0, "1\n2\n3\n4\n5\n6\n7\n8\n", ""),
    (["1", "nan"], 0, "", ""),
    (["nan", "3"], 0, "", ""),
    (["1.", "3"], 0, "1\n2\n3\n", ""),
    ([".5", "2.5"], 0, "0.5\n1.5\n2.5\n", ""),
    (["1", "3", "-1"], 1, "", "seq: needs negative decrement\n"),
    (["0", "0.1", "0.5"], 0, "0\n0.1\n0.2\n0.3\n0.4\n0.5\n", ""),
    (["1", "0.3", "2"], 0, "1\n1.3\n1.6\n1.9\n", ""),
    (["0.1", "0.2", "1"], 0, "0.1\n0.3\n0.5\n0.7\n0.9\n", ""),
    (["0", "0.7", "7"], 0, "0\n0.7\n1.4\n2.1\n2.8\n3.5\n4.2\n4.9\n5.6\n6.3\n7\n", ""),
    (["-0", "2"], 0, "0\n1\n2\n", ""),
    (["-0.0", "0.0"], 0, "0\n", ""),
    (["0", "0"], 0, "0\n", ""),
    (["1", "1"], 0, "1\n", ""),
    ([" 3"], 0, "1\n2\n3\n", ""),
    (["3 "], 2, "", "seq: invalid floating point argument: 3 \n"),
    (["1_0"], 2, "", "seq: invalid floating point argument: 1_0\n"),
    (["1,5"], 2, "", "seq: invalid floating point argument: 1,5\n"),
    (["--format"], 1, "", "seq: option `--format' requires an argument\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["--separator"], 1, "", "seq: option `--separator' requires an argument\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["--terminator"], 1, "", "seq: option `--terminator' requires an argument\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["--sep"], 1, "", "seq: option `--sep' requires an argument\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["3", "--format"], 2, "", "seq: invalid floating point argument: --format\n"),
    (["--f"], 1, "", "seq: option `--f' requires an argument\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["--s", "3"], 1, "", "usage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
    (["--t"], 1, "", "seq: option `--t' requires an argument\nusage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"),
]

@Suite("seq behavior") class seqBehaviorTest : ShellTest {
  let cmd = "seq"
  let suiteBundle = "shell_cmds_seqTest"

  @Test(arguments: seqRecordedResults)
  func matchesTheSystem(_ recorded: ([String], Int, String, String)) async throws {
    let (args, status, output, error) = recorded
    try await run(status: status, output: output, error: error, args: args)
  }

  @Test func firstOfSeveralFormats() async throws {
    try await run(output: "1.00\n1.50\n2.00\n", args: "-f", "%.2f", "1", "0.5", "2")
  }

  /// The value the loop stops short of, because of rounding, is still shown when it prints as the last one.
  @Test func lastValueMissedByRounding() async throws {
    try await run(output: "0.1\n0.2\n0.3\n", args: "0.1", "0.1", "0.3")
    try await run(output: "0\n0.1\n0.2\n0.3\n0.4\n0.5\n0.6\n0.7\n", args: "0", "0.1", "0.7")
  }

  /// An empty argument is a legal one for a long option (`--separator=` joins the numbers).
  @Test(arguments: [(["--separator=", "3"], "123"), (["--terminator=", "3"], "1\n2\n3\n"), (["--separator", "", "3"], "123")])
  func emptyArgumentOfALongOption(_ args: [String], _ expected: String) async throws {
    try await run(output: expected, args: args)
  }

  @Test(arguments: [["--format=", "3"], ["--format", "", "3"]])
  func emptyFormat(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: "seq: invalid format string: `'\n", args: args)
  }

  @Test func manyValues() async throws {
    try await run(output: (1...20000).map { "\($0)\n" }.joined(), args: "20000")
  }
}
