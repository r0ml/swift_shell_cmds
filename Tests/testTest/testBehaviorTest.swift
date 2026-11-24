// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Results recorded from the system's test, for the expressions they were made with, in the directory made by
/// `TestFixtures`: the arguments, the exit status, and what was said on the error output.
let testRecordedResults: [([String], Int, String)] = [
    (["a"], 0, ""),
    ([""], 1, ""),
    (["-n"], 0, ""),
    (["-z"], 0, ""),
    (["-n", ""], 1, ""),
    (["-z", ""], 0, ""),
    (["!"], 0, ""),
    (["!", "a"], 1, ""),
    (["!", ""], 0, ""),
    (["(", ")"], 1, ""),
    (["(", "a", ")"], 0, ""),
    (["a", "=", "a"], 0, ""),
    (["a", "!=", "b"], 0, ""),
    (["1", "-eq", "1"], 0, ""),
    (["1", "-lt", "2", "-a", "3", "-gt", "2"], 0, ""),
    (["!", "", "-o", "x"], 1, ""),
    (["-f", "f", "-a", "-d", "d"], 0, ""),
    (["1", "-eq", "x"], 2, "test: x: bad number\n"),
    (["1", "-eq"], 2, "test: -eq: argument expected\n"),
    (["a", "="], 2, "test: =: argument expected\n"),
    (["(", "a"], 2, "test: closing paren expected\n"),
    (["a", ")"], 2, "test: a: unexpected operator\n"),
    (["a", "b"], 2, "test: a: unexpected operator\n"),
    (["a", "b", "c"], 2, "test: a: unexpected operator\n"),
    (["-a"], 0, ""),
    (["-o"], 0, ""),
    (["!", "!", "a"], 0, ""),
    (["!", "(", "a", ")"], 1, ""),
    (["(", "!", ")"], 0, ""),
    (["99999999999999999999", "-eq", "1"], 2, "test: 99999999999999999999: out of range\n"),
    (["9223372036854775807", "-gt", "9223372036854775806"], 0, ""),
    (["-9223372036854775808", "-lt", "0"], 0, ""),
    (["f", "-nt", "e"], 0, ""),
    (["e", "-ot", "f"], 0, ""),
    (["f", "-ef", "f2"], 0, ""),
    (["f", "-ef", "l"], 0, ""),
    (["f", "-ef", "e"], 1, ""),
    (["-f", "l"], 0, ""),
    (["-h", "l"], 0, ""),
    (["-L", "dangling"], 0, ""),
    (["-e", "dangling"], 1, ""),
    (["-x", "x"], 0, ""),
    (["-x", "ro"], 1, ""),
    (["-w", "ro"], 1, ""),
    (["-r", "ro"], 0, ""),
    (["-u", "u"], 0, ""),
    (["-k", "t"], 0, ""),
    (["-s", "f"], 0, ""),
    (["-s", "e"], 1, ""),
    (["-p", "p"], 0, ""),
    (["-d", "d"], 0, ""),
    (["-c", "/dev/null"], 0, ""),
    (["-t", "0"], 1, ""),
    (["-t", "x"], 2, "test: x: bad number\n"),
    (["-t", "99999999999"], 1, ""),
    (["-O", "f"], 0, ""),
    (["é", "=", "é"], 0, ""),
    (["a", "<", "b"], 0, ""),
    (["b", "<", "a"], 1, ""),
    (["B", ">", "a"], 1, ""),
    (["ro", "1", "/dev/null"], 2, "test: ro: unexpected operator\n"),
    (["-g", "-a", "-ot", "f2"], 2, "test: -a: unexpected operator\n"),
    (["e", "1.5", "-x"], 2, "test: e: unexpected operator\n"),
    (["9", "-ef", "1", "t"], 2, "test: 1: unexpected operator\n"),
    (["-c", "a", "a"], 2, "test: a: unexpected operator\n"),
    (["f"], 0, ""),
    (["1.5", "-1", "-1"], 2, "test: 1.5: unexpected operator\n"),
    ([">", " 5", "5 ", "9"], 2, "test: >: unexpected operator\n"),
    (["-ef", "!=", "d"], 0, ""),
    (["-e", "-1", "abc", "!"], 2, "test: -1: unexpected operator\n"),
    (["-ne", "!="], 2, "test: !=: argument expected\n"),
    (["-gt"], 0, ""),
    (["<", "-lt"], 2, "test: -lt: argument expected\n"),
    (["-k", ">", "9", "-k"], 2, "test: 9: unexpected operator\n"),
    (["10", "u", "-o", "d", "-lt", "-w"], 2, "test: 10: unexpected operator\n"),
    (["-e"], 0, ""),
    (["-ot", "e", "-b", "x"], 2, "test: -ot: unexpected operator\n"),
    ([" 5", "", "-a"], 2, "test:  5: unexpected operator\n"),
    (["-nt", "=="], 2, "test: ==: argument expected\n"),
    (["-d"], 0, ""),
    (["5 ", "-gt"], 2, "test: -gt: argument expected\n"),
    (["abc", "-gt", ")", "dangling"], 2, "test: abc: bad number\n"),
    ([">", "<", "10", "newer"], 2, "test: 10: unexpected operator\n"),
    (["<", "-k", "1"], 2, "test: <: unexpected operator\n"),
    (["newer"], 0, ""),
    (["p", "-z", "-ge", "-o", "-p"], 2, "test: p: unexpected operator\n"),
    (["abc", "u", "p", "-h", "-ne"], 2, "test: abc: unexpected operator\n"),
    (["a", "a", "-x"], 2, "test: a: unexpected operator\n"),
    (["-1", "-d"], 2, "test: -1: unexpected operator\n"),
    (["0", "u", "-e", "=="], 2, "test: 0: unexpected operator\n"),
    (["-p", "-1", "-O"], 2, "test: -1: unexpected operator\n"),
    (["-s", ">", "-k", ")", "==", "-g"], 2, "test: -k: unexpected operator\n"),
    (["abc", "/dev/null", "-ot", "-X", "10"], 2, "test: abc: unexpected operator\n"),
    (["-gt", "9", "dangling", "-s", "(", "-S"], 2, "test: -gt: unexpected operator\n"),
    (["g", "-lt", "p", "<"], 2, "test: g: bad number\n"),
    ([")", "-s", "!", "=="], 2, "test: ): unexpected operator\n"),
    (["10", "e", "-g", "-o"], 2, "test: 10: unexpected operator\n"),
    ([")", "-u", "=", "-L"], 2, "test: ): unexpected operator\n"),
    (["-ge", ")", "-ge", "-x"], 2, "test: -ge: unexpected operator\n"),
    (["10", "-b", "-le", "-ne"], 2, "test: 10: unexpected operator\n"),
    (["-k", "=", "newer", "-e"], 2, "test: newer: unexpected operator\n"),
    (["-O", "-e", "!="], 2, "test: -e: unexpected operator\n"),
    (["l", " 5", "1", "-c"], 2, "test: l: unexpected operator\n"),
    (["12abc", "9", "x"], 2, "test: 12abc: unexpected operator\n"),
    (["12abc", "-1", "ro", "b", "/dev/null", ">"], 2, "test: 12abc: unexpected operator\n"),
    (["-k", "007", "p"], 2, "test: 007: unexpected operator\n"),
    (["-u", "-ge", "-ot", "t", "5 "], 2, "test: -u: bad number\n"),
    (["-nt", "f", "-ge"], 2, "test: -nt: unexpected operator\n"),
    ([")", "-x", "/dev/null", "-nt", "p"], 2, "test: ): unexpected operator\n"),
    (["nofile", "==", "-S", "-gt"], 2, "test: -S: unexpected operator\n"),
    (["-lt", "a", "-e", "-x"], 2, "test: -lt: unexpected operator\n"),
    (["-u", "abc", "1", "-ot"], 2, "test: abc: unexpected operator\n"),
    ([" 5", "b", "dangling", "-ge", "f", "-ot"], 2, "test:  5: unexpected operator\n"),
    (["-eq", "abc"], 2, "test: -eq: unexpected operator\n"),
    (["-ot", "-f", "-d", "12abc"], 2, "test: -ot: unexpected operator\n"),
    (["==", "-k", "-ot", "-ef", "1", "!"], 2, "test: ==: unexpected operator\n"),
    (["-h", "-o", "-e", "d"], 2, "test: -o: unexpected operator\n"),
    (["<", "-s", "=", "abc"], 2, "test: <: unexpected operator\n"),
    (["l", "", "-c", "-a", "==", "x"], 2, "test: l: unexpected operator\n"),
    (["-r", "e", "-k"], 2, "test: e: unexpected operator\n"),
    (["-a", "-g", "p", "-a"], 2, "test: -a: unexpected operator\n"),
    (["(", "0", "=", "==", "-h", "-g"], 2, "test: closing paren expected\n"),
    (["d", "a"], 2, "test: d: unexpected operator\n"),
    (["=", "-X", "-gt", "=="], 2, "test: =: unexpected operator\n"),
    (["-u"], 0, ""),
    (["-le", "a", "p", "f"], 2, "test: -le: unexpected operator\n"),
    (["-p", "f2", "007", "e"], 2, "test: f2: unexpected operator\n"),
    (["-f", "-k", "-ef", "-g", "-r"], 2, "test: -k: unexpected operator\n"),
    (["==", "-u", "g"], 2, "test: ==: unexpected operator\n"),
    (["f", "-d", "=", "-g"], 2, "test: f: unexpected operator\n"),
    (["abc", "-1", "-k", "-h"], 2, "test: abc: unexpected operator\n"),
    (["-X", "0", "-f", "ro"], 2, "test: -X: unexpected operator\n"),
    (["-n", "("], 0, ""),
    (["g", "l"], 2, "test: g: unexpected operator\n"),
    (["-f", "g", "-w", "-s"], 2, "test: g: unexpected operator\n"),
    (["12abc", "/dev/null"], 2, "test: 12abc: unexpected operator\n"),
    (["==", "-c", "0"], 2, "test: ==: unexpected operator\n"),
    (["9", "-x", "1"], 2, "test: 9: unexpected operator\n"),
    (["1.5", "x"], 2, "test: 1.5: unexpected operator\n"),
    (["-ot", "t"], 2, "test: -ot: unexpected operator\n"),
    (["u", "", "-w", "b"], 2, "test: u: unexpected operator\n"),
    ([">", "-s"], 2, "test: >: unexpected operator\n"),
    (["-lt", "-nt", "u", "b", "==", "0"], 2, "test: u: unexpected operator\n"),
    (["12abc", "!", "g", "-z"], 2, "test: 12abc: unexpected operator\n"),
    (["=", "-O", "b", "-z"], 2, "test: =: unexpected operator\n"),
    (["-p", "-ef", "10", "a"], 2, "test: 10: unexpected operator\n"),
    (["p", "dangling"], 2, "test: p: unexpected operator\n"),
    (["-L", "-p"], 1, ""),
    (["-ef", "-u", "-k"], 2, "test: -ef: unexpected operator\n"),
    (["0"], 0, ""),
    (["12abc", "/dev/null", "newer", "-s", "1.5"], 2, "test: 12abc: unexpected operator\n"),
    (["-ot", "-lt", "-z"], 2, "test: -ot: bad number\n"),
    (["-ne", "-ge", "-ef", "-ot"], 2, "test: -ne: bad number\n"),
    (["-lt", "==", "-d"], 1, ""),
    (["-O", "p", "1.5", "9"], 2, "test: p: unexpected operator\n"),
    (["g", "nofile", "p", "p", "9"], 2, "test: g: unexpected operator\n"),
    ([" 5", "x", "-s"], 2, "test:  5: unexpected operator\n"),
    (["-ge", "f", "-f", "-g", "!=", "-f"], 2, "test: -ge: unexpected operator\n"),
    (["-u", "-u", "nofile", "007"], 2, "test: -u: unexpected operator\n"),
    (["1", "t", "-nt"], 2, "test: 1: unexpected operator\n"),
    (["-g", "0", "-o", "/dev/null", ")"], 2, "test: /dev/null: unexpected operator\n"),
    (["=", "-z", "p"], 2, "test: =: unexpected operator\n"),
    (["p", "-ge", "-nt", ">", "u", "d"], 2, "test: p: bad number\n"),
    (["-g", "0", "", "-eq", "==", "-p"], 2, "test: 0: unexpected operator\n"),
    (["1", "p", " 5"], 2, "test: 1: unexpected operator\n"),
    (["-w", "-le"], 1, ""),
    (["9", "-u", "-le", "="], 2, "test: 9: unexpected operator\n"),
    (["-u", "1"], 1, ""),
    (["10", "5 ", "x"], 2, "test: 10: unexpected operator\n"),
    (["(", "f", "-u", "u", "-b"], 2, "test: closing paren expected\n"),
    (["-1", "x", "p", "-O", "-ge"], 2, "test: -1: unexpected operator\n"),
    (["t", "-z"], 2, "test: t: unexpected operator\n"),
    (["dangling", "-g", "ro", "-a", "ro", "-h"], 2, "test: dangling: unexpected operator\n"),
    (["u", "ro", "-o", "-x", "-b"], 2, "test: u: unexpected operator\n"),
    (["ro", "p", "007", "10"], 2, "test: ro: unexpected operator\n"),
    (["007", "-X", "-n", "newer", ">"], 2, "test: 007: unexpected operator\n"),
    (["dangling", "1"], 2, "test: dangling: unexpected operator\n"),
    (["1.5", "d"], 2, "test: 1.5: unexpected operator\n"),
    (["-lt", "-s", "-f", "-ot", "-O", "a"], 2, "test: -lt: unexpected operator\n"),
    (["<"], 0, ""),
    (["12abc", "/dev/null", "b", "<", "-k", "dangling"], 2, "test: 12abc: unexpected operator\n"),
    (["-w", ">", "a", "a"], 2, "test: a: unexpected operator\n"),
    (["-g", "-a"], 1, ""),
    (["-f", "-a"], 1, ""),
    (["u", "-h", "-a", "ro"], 2, "test: u: unexpected operator\n"),
    (["=", "-nt", "nofile"], 1, ""),
    (["-e", ">"], 1, ""),
    (["f", "=", "a", "l", "-c"], 2, "test: a: unexpected operator\n"),
    (["d", "ro", "-f"], 2, "test: d: unexpected operator\n"),
    (["f2", "-ot", "a", "-eq"], 2, "test: a: unexpected operator\n"),
    (["<", "-1"], 2, "test: <: unexpected operator\n"),
    (["!", "-h", "-eq"], 0, ""),
    (["p", "g", "l", "l"], 2, "test: p: unexpected operator\n"),
    (["ro", "a"], 2, "test: ro: unexpected operator\n"),
    (["-d", "!", "d", "-n"], 2, "test: !: unexpected operator\n"),
    (["a", "-le", " 5", "-ne", "-lt"], 2, "test: a: bad number\n"),
    (["1"], 0, ""),
    (["abc", "-b", "-d"], 2, "test: abc: unexpected operator\n"),
    (["", "-ne", ">", "-b", "-n"], 2, "test: : bad number\n"),
    (["-d", "-1", "-c", "ro", "1", "-X"], 2, "test: -1: unexpected operator\n"),
    (["-s", "f", "f2", "a", "-e", "ro"], 2, "test: f: unexpected operator\n"),
    (["f", "p", "-z"], 2, "test: f: unexpected operator\n"),
    (["-lt", "-r", "-u", "1.5", " 5", ")"], 2, "test: -lt: unexpected operator\n"),
    (["!=", "-O", "-lt"], 2, "test: !=: unexpected operator\n"),
    (["-le", "-lt", "-a"], 2, "test: -le: bad number\n"),
    (["-h"], 0, ""),
    (["-ge", "abc", "abc", "-z", "-s"], 2, "test: -ge: unexpected operator\n"),
    (["p", "nofile", "-1", "-r", "nofile"], 2, "test: p: unexpected operator\n"),
    ([" 5", "-eq", "-k", "-g"], 2, "test: -k: bad number\n"),
    ([" 5", "-ot"], 2, "test: -ot: argument expected\n"),
    (["f2"], 0, ""),
    (["-ef", "d", ">"], 2, "test: -ef: unexpected operator\n"),
    (["-L", "-g", "-w", "-b", "u"], 2, "test: -g: unexpected operator\n"),
    (["-e", "-le", "d"], 2, "test: -e: bad number\n"),
    (["=", "=", "t"], 1, ""),
    (["dangling"], 0, ""),
    (["-x", "<", "e", ")"], 2, "test: e: unexpected operator\n"),
    (["t", "p", "dangling"], 2, "test: t: unexpected operator\n"),
    (["-ge", "5 ", "-k", "-O"], 2, "test: -ge: unexpected operator\n"),
    (["", "-z"], 2, "test: unexpected operator\n"),
    (["-f", "-r", "f", "-ef"], 2, "test: -r: unexpected operator\n"),
    (["f2", "-nt", "-a", "nofile"], 2, "test: -a: unexpected operator\n"),
    (["==", "<", "("], 1, ""),
    (["-1", "t"], 2, "test: -1: unexpected operator\n"),
    (["9", "12abc", "g", "-x", "-e"], 2, "test: 9: unexpected operator\n"),
    (["!=", "-e", ")"], 2, "test: !=: unexpected operator\n"),
    (["-ne", "9"], 2, "test: -ne: unexpected operator\n"),
    (["l", "0", "/dev/null", "==", "9"], 2, "test: l: unexpected operator\n"),
    (["007", "-eq", "f2", "-ne", "t"], 2, "test: f2: bad number\n"),
    (["-s"], 0, ""),
    (["-O", "t", ">"], 2, "test: t: unexpected operator\n"),
    (["-u", "-ef", "-n"], 1, ""),
    (["nofile", "f", "007", "1", "/dev/null", "dangling"], 2, "test: nofile: unexpected operator\n"),
    (["0", "-nt", "f2", "-c"], 2, "test: f2: unexpected operator\n"),
    (["9", "f2", "-le", "f2"], 2, "test: 9: unexpected operator\n"),
    ([" 5", "5 "], 2, "test:  5: unexpected operator\n"),
    (["-nt", "10", "-p", "newer"], 2, "test: -nt: unexpected operator\n"),
    (["-w", "-u", "-ot"], 2, "test: -u: unexpected operator\n"),
    (["a", "f", "-h", "-ot"], 2, "test: a: unexpected operator\n"),
    (["t", "-s", "==", "d"], 2, "test: t: unexpected operator\n"),
    (["-k", "-lt"], 1, ""),
    (["-gt", "-ot", "abc"], 1, ""),
    (["-h", "dangling", "/dev/null", "=="], 2, "test: dangling: unexpected operator\n"),
    (["-gt", "g", "-O", "-d", "ro"], 2, "test: -gt: unexpected operator\n"),
    (["-e", "-z", "("], 2, "test: -z: unexpected operator\n"),
    (["abc", "("], 2, "test: abc: unexpected operator\n"),
    (["-k", "-d"], 1, ""),
    (["-ef", "-a", "dangling"], 0, ""),
    (["-lt", "a", "newer", "f", "abc", "-le"], 2, "test: -lt: unexpected operator\n"),
    (["d"], 0, ""),
    (["-p", "-ef", "-O", "newer"], 2, "test: -O: unexpected operator\n"),
    (["1.5"], 0, ""),
    (["-c", "e", "-g"], 2, "test: e: unexpected operator\n"),
    ([")", "-g"], 2, "test: ): unexpected operator\n"),
    (["ro"], 0, ""),
    (["-r", "-L", "-d"], 2, "test: -L: unexpected operator\n"),
    (["-d", "-ot", "e", "-1", "-gt"], 2, "test: e: unexpected operator\n"),
    (["!=", "007", "-f"], 2, "test: !=: unexpected operator\n"),
    (["-nt", "1.5"], 2, "test: -nt: unexpected operator\n"),
    (["-e", "007", "(", "b", "-g"], 2, "test: 007: unexpected operator\n"),
    (["=", "f", "", "-1"], 2, "test: =: unexpected operator\n"),
    (["t", "t", "-ot", "p", "-x", "0"], 2, "test: t: unexpected operator\n"),
    (["d", "-h", ">"], 2, "test: d: unexpected operator\n"),
    (["b", "-u", "-z", "t", "-le", "l"], 2, "test: b: unexpected operator\n"),
    (["9"], 0, ""),
]

/// The files the recorded results were made with.
final class TestFixtures {
  let root: String

  init() {
    var template = Array("/tmp/testtestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    func file(_ name: String, _ text: String, mode: mode_t = 0o644) {
      let fd = open(root + "/" + name, O_CREAT | O_WRONLY | O_TRUNC, 0o644)
      _ = text.withCString { write(fd, $0, strlen($0)) }
      close(fd)
      chmod(root + "/" + name, mode)
    }
    file("f", "data\n")
    file("e", "")
    mkdir(root + "/d", 0o755)
    symlink("f", root + "/l")
    mkfifo(root + "/p", 0o644)
    file("x", "#!/bin/sh\n", mode: 0o755)
    file("ro", "r", mode: 0o444)
    file("u", "u", mode: 0o4755)
    file("g", "g", mode: 0o2755)
    mkdir(root + "/t", 0o755)
    chmod(root + "/t", 0o1777)
    symlink("nowhere", root + "/dangling")
    link(root + "/f", root + "/f2")
    file("newer", "n")
    for (name, seconds) in [("f", 2000), ("e", 1000), ("newer", 3000)] {
      var times = [timeval(tv_sec: seconds, tv_usec: 0), timeval(tv_sec: seconds, tv_usec: 0)]
      utimes(root + "/" + name, &times)
    }
  }

  func remove() {
    for name in ["f", "e", "l", "p", "x", "ro", "u", "g", "dangling", "f2", "newer"] {
      chmod(root + "/" + name, 0o644)
      unlink(root + "/" + name)
    }
    rmdir(root + "/d")
    rmdir(root + "/t")
    rmdir(root)
  }
}

/// Serialized: `run` changes PATH for the whole process.
@Suite("test behavior", .serialized) final class testBehaviorTest : ShellTest {
  let cmd = "test"
  let suiteBundle = "shell_cmds_testTest"

  @Test(arguments: testRecordedResults)
  func matchesTheSystem(_ recorded: ([String], Int, String)) async throws {
    let (args, status, error) = recorded
    let fixtures = TestFixtures()
    defer { fixtures.remove() }
    try await run(withStdin: "", status: status, output: "", error: error, args: args, cd: FilePath(fixtures.root))
  }

  /// Comparison of strings is by bytes: composed and decomposed forms of a letter are not the same.
  @Test func stringsAreBytes() async throws {
    try await run(status: 1, args: "\u{e9}", "=", "e\u{301}")
    try await run(status: 0, args: "\u{e9}", "=", "\u{e9}")
    try await run(status: 0, args: "Z", "<", "a")
  }

  @Test func noExpressionIsFalse() async throws {
    try await run(status: 1, output: "", error: "", args: [String]())
  }

  // MARK: [

  /// Called by the name `[`, the last argument has to be `]`.
  @Test func bracketForm() async throws {
    let directory = TestFixtures()
    defer { directory.remove() }
    guard let test = searchPath(for: "test") else { Issue.record("no test"); return }
    let link = directory.root + "/["
    #expect(symlink(test, link) == 0)
    defer { unlink(link) }
    for (args, status, error) in [(["a", "=", "a", "]"], 0, ""), (["a", "=", "b", "]"], 1, ""), (["-f", "f", "]"], 0, ""),
                                  (["]"], 1, ""), (["a", "=", "a"], 2, "[: missing ]\n"), ([], 2, "[: missing ]\n"),
                                  (["!", "-d", "d", "]"], 1, ""), (["(", "a", ")", "]"], 0, "")] as [([String], Int, String)] {
      let process = try await DarwinProcess().run(link, args: args, cd: FilePath(directory.root))
      #expect(Int(process.code) == status, "\(args)")
      #expect(process.error == error, "\(args)")
    }
  }
}
