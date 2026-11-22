// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A tree of directories and links for the tests to work in.  The root is the real path of a directory of its own
/// (/tmp is itself a link), so what pwd -P says can be compared with it.
final class PwdTree {
  let root: String
  private var made = [String]()

  init() {
    var template = Array("/tmp/pwdtestXXXXXX".utf8CString)
    let made = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
    root = realpath(made, &resolved) != nil ? String(cString: resolved) : made

    directory("real")
    directory("real/sub")
    directory("sp ace")
    directory("ünï/日本")
    symlink("link", to: "real")
    symlink("linksub", to: "real/sub")
    symlink("abslink", to: root + "/real")
    symlink("linklink", to: "link")
  }

  func path(_ name: String) -> String { name.isEmpty ? root : root + "/" + name }

  /// `text` with an @ at the start standing for the root.
  func expand(_ text: String) -> String { text.hasPrefix("@") ? root + text.dropFirst() : text }

  func directory(_ name: String) {
    var current = root
    for part in name.split(separator: "/") {
      current += "/" + part
      if mkdir(current, 0o755) == 0 { made.append(current) }
    }
  }

  func symlink(_ name: String, to target: String) {
    if Darwin.symlink(target, root + "/" + name) == 0 { made.append(root + "/" + name) }
  }

  func remove() {
    for item in made.reversed() {
      if unlink(item) != 0 { rmdir(item) }
    }
    rmdir(root)
  }
}

@Suite("pwd tests") final class pwdTest : ShellTest {
  let cmd = "pwd"
  let suiteBundle = "shell_cmds_pwdTest"

  static let usageText = "usage: pwd [-L | -P]\n"

  func pwd(_ t: PwdTree, in dir: String, _ pwdVariable: String?, _ args: String..., output: String, status: Int = 0) async throws {
    var env = [String: String]()
    if let pwdVariable { env["PWD"] = pwdVariable }
    try await run(status: status, output: output, args: args, env: env, cd: FilePath(t.path(dir)))
  }

  // MARK: the physical path

  @Test(arguments: ["", "real", "real/sub", "sp ace", "ünï/日本", "link", "linksub", "abslink", "linklink"])
  func physicalPathResolvesLinks(_ dir: String) async throws {
    let t = PwdTree()
    defer { t.remove() }
    let expected: [String: String] = ["link": "real", "linksub": "real/sub", "abslink": "real", "linklink": "real"]
    let real = t.path(expected[dir] ?? dir)
    try await pwd(t, in: dir, nil, "-P", output: real + "\n")
    try await pwd(t, in: dir, t.path(dir), "-P", output: real + "\n")
  }

  @Test func physicalPathOfTheRoot() async throws {
    try await run(output: "/\n", args: "-P", cd: FilePath("/"))
    try await run(output: "/\n", args: [String](), cd: FilePath("/"))
  }

  // MARK: the logical path

  /// $PWD is used as it is when it names the working directory, links and all.
  @Test(arguments: ["link", "linksub", "abslink", "linklink", "real", "sp ace"])
  func logicalPathIsWhatPwdSays(_ dir: String) async throws {
    let t = PwdTree()
    defer { t.remove() }
    try await pwd(t, in: dir, t.path(dir), output: t.path(dir) + "\n")
    try await pwd(t, in: dir, t.path(dir), "-L", output: t.path(dir) + "\n")
  }

  @Test func linkAndRealNameAreTheSameDirectory() async throws {
    let t = PwdTree()
    defer { t.remove() }
    // the working directory is real, and $PWD names it through a link
    try await pwd(t, in: "real", t.path("link"), output: t.path("link") + "\n")
    try await pwd(t, in: "link", t.path("real"), output: t.path("real") + "\n")
    try await pwd(t, in: "real", t.path("abslink"), output: t.path("abslink") + "\n")
  }

  /// Slashes at the end or doubled are left alone.
  @Test(arguments: ["@/real/", "@/real//", "@//real", "@/real///"])
  func logicalPathIsNotCleanedUp(_ value: String) async throws {
    let t = PwdTree()
    defer { t.remove() }
    let v = t.expand(value)
    try await pwd(t, in: "real", v, output: v + "\n")
  }

  @Test func physicalOptionIgnoresPwd() async throws {
    let t = PwdTree()
    defer { t.remove() }
    try await pwd(t, in: "link", t.path("link"), "-P", output: t.path("real") + "\n")
    try await pwd(t, in: "real", t.path("link"), "-P", output: t.path("real") + "\n")
  }

  // MARK: a $PWD that can't be used

  /// A $PWD that isn't an absolute path to the working directory is no good: the physical path is used.
  @Test(arguments: [("link", ""), ("link", "real"), ("link", "."), ("link", "/nonexistent"), ("link", "/tmp"), ("link", "/"),
                    ("link", "//"), ("real", "@/sp ace"), ("link", "@/real/sub"), ("link", "@/linksub"),
                    ("real", "@/link/sub"), ("sp ace", "@/ünï")])
  func uselessPwdFallsBackToThePhysicalPath(_ dir: String, _ value: String) async throws {
    let t = PwdTree()
    defer { t.remove() }
    let real = ["link": "real", "linksub": "real/sub"][dir] ?? dir
    try await pwd(t, in: dir, t.expand(value), output: t.path(real) + "\n")
  }

  /// Paths with "." or ".." in them aren't logical paths, even if they lead to the working directory.
  @Test(arguments: ["@/real/.", "@/./real", "@/real/./", "@/real/sub/..", "@/linksub/..", "@/real/../real", "@/link/sub/..", "@/link/."])
  func dotsDisqualifyPwd(_ value: String) async throws {
    let t = PwdTree()
    defer { t.remove() }
    try await pwd(t, in: "real", t.expand(value), output: t.path("real") + "\n")
  }

  @Test func unsetPwd() async throws {
    let t = PwdTree()
    defer { t.remove() }
    try await pwd(t, in: "link", nil, output: t.path("real") + "\n")
  }

  @Test func veryLongPwd() async throws {
    let t = PwdTree()
    defer { t.remove() }
    try await pwd(t, in: "link", "/" + String(repeating: "a", count: 5000), output: t.path("real") + "\n")
  }

  // MARK: options

  @Test(arguments: [(["-L"], true), (["-P"], false), (["-LP"], false), (["-PL"], true), (["-L", "-P"], false), (["-P", "-L"], true),
                    (["-LL"], true), (["-PP"], false), ([], true)])
  func lastOptionWins(_ args: [String], _ logical: Bool) async throws {
    let t = PwdTree()
    defer { t.remove() }
    let expected = logical ? t.path("link") : t.path("real")
    var env = ["PWD": t.path("link")]
    env["PWD"] = t.path("link")
    try await run(output: expected + "\n", args: args, env: env, cd: FilePath(t.path("link")))
  }

  @Test(arguments: [["x"], ["-x"], ["-L", "x"], ["-P", "--", "x"], ["-"], ["-LPx"], ["-?"], ["-h"], ["--", "-P"], ["a", "b"]])
  func usageErrors(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Regex<Substring>(verbatim: Self.usageText), args: args)
  }

  @Test func doubleDashEndsTheOptions() async throws {
    let t = PwdTree()
    defer { t.remove() }
    try await run(output: t.path("real") + "\n", args: "--", env: ["PWD": t.path("real")], cd: FilePath(t.path("real")))
    try await run(output: t.path("real") + "\n", args: "-P", "--", env: ["PWD": t.path("link")], cd: FilePath(t.path("link")))
  }

  // MARK: a directory that is gone

  /// The path of the pwd under test, found the way `run` finds it.
  func pwdExecutable() throws -> String {
    if let wd = Environment["XCTestBundlePath"] {
      let p = Environment["PATH"] ?? ""
      try Environment.setenv("PATH", "\(FilePath(wd).removingLastComponent().string):\(p)")
    }
    guard let path = searchPath(for: cmd) else { throw POSIXErrno(ENOENT) }
    return path
  }

  @Test(arguments: [[String](), ["-P"], ["-L"]])
  func workingDirectoryThatNoLongerExists(_ args: [String]) async throws {
    let t = PwdTree()
    defer { t.remove() }
    t.directory("doomed")
    let path = try pwdExecutable()
    let script = "rmdir \"$PWD\" && exec \"$0\" \"$@\""
    let result = try await DarwinProcess().run("/bin/sh", args: ["-c", script, path] + args, env: ["PWD": t.path("doomed")],
                                               cd: FilePath(t.path("doomed")))
    #expect(result.code == 1)
    #expect(result.data.isEmpty)
    #expect(result.error == "pwd: .: No such file or directory\n")
  }
}
