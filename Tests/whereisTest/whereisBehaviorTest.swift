// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Results recorded from the system's whereis, for the directories made by `WhereisFixtures`, run with the
/// environment `WhereisFixtures.environment`: the arguments, the exit status, the standard output and the error output.
let whereisRecordedResults: [([String], Int, String, String)] = [
    (["-b", "ls"], 0, "ls: /bin/ls\n", ""),
    (["-b", "nosuchthing_zz"], 0, "nosuchthing_zz:\n", ""),
    (["-bq", "ls"], 0, "/bin/ls\n", ""),
    (["-bu", "ls", "nosuchthing_zz"], 0, "nosuchthing_zz:\n", ""),
    (["-buq", "nosuchthing_zz"], 0, "", ""),
    (["-b", "ls", "cat", "sh"], 0, "ls: /bin/ls\ncat: /bin/cat\nsh: /bin/sh\n", ""),
    (["-b", "/bin/ls"], 0, "ls: /bin/ls\n", ""),
    (["-b", "a/b/c/ls"], 0, "ls: /bin/ls\n", ""),
    (["-b", "ls.gz"], 0, "ls: /bin/ls\n", ""),
    (["-b", "ls.Z"], 0, "ls: /bin/ls\n", ""),
    (["-b", "ls.z"], 0, "ls: /bin/ls\n", ""),
    (["-b", "ls.bz2"], 0, "ls: /bin/ls\n", ""),
    (["-b", "ls.gz.gz"], 0, "ls.gz:\n", ""),
    (["-b", ".gz"], 0, ".gz:\n", ""),
    (["-b", "x.gz"], 0, "x:\n", ""),
    (["-b", "-B", "b1", "b2", "-f", "mytool"], 0, "mytool: b1/mytool\n", ""),
    (["-bB", "b1", "-f", "mytool"], 0, "mytool: b1/mytool\n", ""),
    (["-b", "-B", "b1:b2", "-f", "mytool"], 0, "mytool: b1/mytool\n", ""),
    (["-a", "-b", "-B", "b1", "b2", "-f", "mytool"], 0, "mytool: b1/mytool b2/mytool\n", ""),
    (["-ab", "-B", "b2", "b1", "-f", "mytool"], 0, "mytool: b2/mytool b1/mytool\n", ""),
    (["-b", "-B", "b1", "-B", "b2", "-f", "mytool"], 0, "mytool: b2/mytool\n", ""),
    (["-b", "-B", "b1", "b1", "b1", "-f", "mytool"], 0, "mytool: b1/mytool\n", ""),
    (["-b", "-B", "-f", "mytool"], 0, "mytool:\n", ""),
    (["-b", "-B", "b1", "-f", "plain"], 0, "plain:\n", ""),
    (["-b", "-B", "b1", "-f", "adir"], 0, "adir:\n", ""),
    (["-b", "-B", "b1", "b2", "b3", "-f", "onlyb3", "mytool", "plain"], 0, "onlyb3: b3/onlyb3\nmytool: b1/mytool\nplain:\n", ""),
    (["-b", "-B", ":b1::b2:", "-f", "mytool"], 0, "mytool: b1/mytool\n", ""),
    (["-b", "-B", "b1", "-M", "b1", "-f", "mytool"], 0, "mytool: b1/mytool\n", ""),
    (["-b", "-B", "/bin", "-f", "ls", "ls"], 0, "ls: /bin/ls\nls: /bin/ls\n", ""),
    (["-b", "-B", "relative/dir", "-f", "x"], 0, "x:\n", ""),
    (["-bq", "-B", "/bin", "-f", "ls"], 0, "/bin/ls\n", ""),
    (["-m", "-M", "m1", "-f", "mytool"], 0, "mytool: m1/man1/mytool.1\n", ""),
    (["-m", "-M", "m1:m2", "-f", "mytool"], 0, "mytool: m1/man1/mytool.1\n", ""),
    (["-a", "-m", "-M", "m1", "m2", "-f", "mytool"], 0, "mytool: m1/man1/mytool.1 m2/man1/mytool.1\n", ""),
    (["-m", "-M", "-f", "mytool"], 0, "mytool:\n", ""),
    (["-bm", "-B", "b1", "-M", "m1", "-f", "mytool"], 0, "mytool: b1/mytool m1/man1/mytool.1\n", ""),
    (["-B", "b1", "-M", "m1", "-f", "mytool"], 0, "mytool: b1/mytool m1/man1/mytool.1\n", ""),
    (["-u", "-B", "b1", "-M", "m1", "-f", "mytool", "ls"], 0, "ls:\n", ""),
    (["-q", "-B", "b1", "-M", "m1", "-f", "mytool"], 0, "b1/mytool m1/man1/mytool.1\n", ""),
    (["-B", "b1", "mytool"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-B", "b1", "-f"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-f", "ls"], 0, "ls: /bin/ls /usr/share/man/man1/ls.1\n", ""),
    (["-f"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-x", "ls"], 64, "", "whereis: illegal option -- x\nusage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-z"], 64, "", "whereis: illegal option -- z\nusage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    ([], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-q"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-B"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-M"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-B", "-f"], 64, "", "usage: whereis [-abmqu] [-BM dir ... -f] program ...\n"),
    (["-b", "--", "ls"], 0, "ls: /bin/ls\n", ""),
    (["-bf", "ls"], 0, "ls: /bin/ls\n", ""),
    (["-fb", "ls"], 0, "-fb:\nls: /bin/ls /usr/share/man/man1/ls.1\n", ""),
]

/// Directories of programs and of manual pages to look in.
final class WhereisFixtures {
  let root: String

  init() {
    var template = Array("/tmp/whereistestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    for dir in ["b1", "b2", "b3", "b1/adir", "m1", "m1/man1", "m2", "m2/man1"] {
      mkdir(root + "/" + dir, 0o755)
    }
    file("b1/mytool", "#!/bin/sh\n", 0o755)
    file("b2/mytool", "#!/bin/sh\n", 0o755)
    file("b1/plain", "#!/bin/sh\n", 0o644)
    file("b3/onlyb3", "#!/bin/sh\n", 0o755)
    file("b2/ls", "#!/bin/sh\n", 0o755)
    file("m1/man1/mytool.1", ".TH MYTOOL 1\n.SH NAME\nmytool \\- x\n", 0o644)
    file("m2/man1/mytool.1", ".TH MYTOOL 1\n", 0o644)
  }

  func file(_ name: String, _ text: String, _ mode: mode_t) {
    let fd = open(root + "/" + name, O_CREAT | O_WRONLY | O_TRUNC, 0o644)
    _ = text.withCString { write(fd, $0, strlen($0)) }
    close(fd)
    chmod(root + "/" + name, mode)
  }

  /// What the results were recorded with: the usual directories to look in, and no manual path of its own.
  func environment() -> [String: String] {
    ["PATH": "/usr/bin:/bin", "HOME": root]
  }

  func remove() {
    for name in ["b1/mytool", "b2/mytool", "b1/plain", "b3/onlyb3", "b2/ls", "m1/man1/mytool.1", "m2/man1/mytool.1"] {
      unlink(root + "/" + name)
    }
    for dir in ["b1/adir", "b1", "b2", "b3", "m1/man1", "m1", "m2/man1", "m2"] {
      rmdir(root + "/" + dir)
    }
    rmdir(root)
  }
}

@Suite("whereis behavior", .serialized) final class whereisBehaviorTest : ShellTest {
  let cmd = "whereis"
  let suiteBundle = "shell_cmds_whereisTest"

  @Test(arguments: whereisRecordedResults)
  func matchesTheSystem(_ recorded: ([String], Int, String, String)) async throws {
    let (args, status, output, error) = recorded
    let fixtures = WhereisFixtures()
    defer { fixtures.remove() }
    try await run(withStdin: "", status: status, output: output, error: error, args: args, env: fixtures.environment(), cd: FilePath(fixtures.root))
  }

  @Test func userPathIsSearchedToo() async throws {
    let fixtures = WhereisFixtures()
    defer { fixtures.remove() }
    var environment = fixtures.environment()
    environment["PATH"] = "\(fixtures.root)/b1:\(fixtures.root)/b2:/usr/bin:/bin"
    try await run(withStdin: "", output: "mytool: \(fixtures.root)/b1/mytool\n", error: "", args: "-b", "mytool", env: environment, cd: FilePath(fixtures.root))
    try await run(withStdin: "", output: "mytool: \(fixtures.root)/b1/mytool \(fixtures.root)/b2/mytool\n", error: "", args: "-ba", "mytool", env: environment, cd: FilePath(fixtures.root))
  }

  @Test func theStandardPathComesFirst() async throws {
    let fixtures = WhereisFixtures()
    defer { fixtures.remove() }
    var environment = fixtures.environment()
    environment["PATH"] = "\(fixtures.root)/b2:/usr/bin:/bin"
    try await run(withStdin: "", output: "ls: /bin/ls \(fixtures.root)/b2/ls\n", error: "", args: "-ba", "ls", env: environment, cd: FilePath(fixtures.root))
  }

  @Test func theManualPathComesFromTheEnvironment() async throws {
    let fixtures = WhereisFixtures()
    defer { fixtures.remove() }
    var environment = fixtures.environment()
    environment["MANPATH"] = "\(fixtures.root)/m1"
    try await run(withStdin: "", output: "mytool: \(fixtures.root)/m1/man1/mytool.1\n", error: "", args: "-m", "mytool", env: environment, cd: FilePath(fixtures.root))
  }
}
