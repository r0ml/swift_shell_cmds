// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A tree of directories, files and links to resolve paths in.  The root is itself a real path (/tmp is a link).
final class RealpathTree {
  let root: String
  private var made = [String]()

  init() {
    var template = Array("/tmp/realpathtestXXXXXX".utf8CString)
    let made = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
    root = realpath(made, &resolved) != nil ? String(cString: resolved) : made

    directory("real")
    directory("real/sub")
    directory("sp ace/dir")
    directory("ünï/日本")
    file("real/file")
    symlink("link", to: "real")
    symlink("linksub", to: "real/sub")
    symlink("abslink", to: root + "/real")
    symlink("linklink", to: "link")
    symlink("linkfile", to: "real/file")
    symlink("dangling", to: "nowhere")
    symlink("loop1", to: "loop2")
    symlink("loop2", to: "loop1")
    symlink("real/sub/up", to: "..")
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

  func file(_ name: String) {
    close(open(root + "/" + name, O_CREAT | O_WRONLY, 0o644))
    made.append(root + "/" + name)
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

@Suite("realpath tests") final class realpathTest : ShellTest {
  let cmd = "realpath"
  let suiteBundle = "shell_cmds_realpathTest"

  static let usageText = "usage: realpath [-q] [path ...]\n"

  func resolve(_ t: RealpathTree, _ args: [String], in dir: String = "", output: String, error: String = "", status: Int = 0) async throws {
    try await run(status: status, output: output, error: error, args: args.map { t.expand($0) }, cd: FilePath(t.path(dir)))
  }

  // MARK: resolving

  @Test(arguments: [("@/real", "real"), ("@/real/", "real"), ("@/real//", "real"), ("@//real", "real"), ("@/real/.", "real"),
                    ("@/real/./sub", "real/sub"), ("@/real/sub/..", "real"), ("@/real/sub/../sub", "real/sub"), ("@/link", "real"),
                    ("@/link/", "real"), ("@/link/sub", "real/sub"), ("@/linksub", "real/sub"), ("@/linksub/..", "real"),
                    ("@/abslink", "real"), ("@/linklink", "real"), ("@/linkfile", "real/file"), ("@/real/file", "real/file"),
                    ("@/real/sub/up", "real"), ("@/real/sub/up/sub", "real/sub"), ("@/sp ace/dir", "sp ace/dir"),
                    ("@/sp ace/../real", "real"), ("@/ünï/日本", "ünï/日本"), ("@/ünï/日本/..", "ünï"), ("@/real/../real/../real", "real"),
                    ("@/real/file/", "real/file"), ("@/real/file/..", "real")])
  func resolvesToThePhysicalPath(_ path: String, _ expected: String) async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, [path], output: t.path(expected) + "\n")
  }

  @Test(arguments: [("real", "real"), ("real/", "real"), ("link", "real"), ("linksub/..", "real"), ("./real", "real"),
                    ("real/sub/..", "real"), ("sp ace/dir", "sp ace/dir"), (".", ""), ("./", "")])
  func relativePathsAreResolvedFromTheWorkingDirectory(_ path: String, _ expected: String) async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, [path], output: t.path(expected) + "\n")
  }

  @Test func relativePathWithDotDotFromAnotherDirectory() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["../real"], in: "sp ace", output: t.path("real") + "\n")
    try await resolve(t, ["../.."], in: "real/sub", output: t.root + "\n")
  }

  @Test(arguments: ["", "real", "real/sub", "link", "linksub", "sp ace/dir"])
  func noPathMeansTheWorkingDirectory(_ dir: String) async throws {
    let t = RealpathTree()
    defer { t.remove() }
    let physical = ["link": "real", "linksub": "real/sub"][dir] ?? dir
    try await resolve(t, [], in: dir, output: t.path(physical) + "\n")
  }

  @Test func theRootDirectory() async throws {
    try await run(output: "/\n", args: "/")
    try await run(output: "/\n", args: "//")
    try await run(output: "/\n", args: "///")
    try await run(output: "/\n", args: "/.")
    try await run(output: "/\n", args: "/..")
  }

  @Test func severalPathsAreAllWritten() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["@/link", "@/linksub", "@/real/file"], output: t.path("real") + "\n" + t.path("real/sub") + "\n" + t.path("real/file") + "\n")
  }

  // MARK: paths that can't be resolved

  @Test(arguments: [("@/nonexist", "No such file or directory"), ("@/nonexist/x", "No such file or directory"),
                    ("@/real/nonexist", "No such file or directory"), ("@/real/nonexist/..", "No such file or directory"),
                    ("@/dangling", "No such file or directory"), ("@/dangling/x", "No such file or directory"),
                    ("@/loop1", "Too many levels of symbolic links"), ("@/loop2/x", "Too many levels of symbolic links"),
                    ("@/real/file/x", "Not a directory")])
  func unresolvablePaths(_ path: String, _ why: String) async throws {
    let t = RealpathTree()
    defer { t.remove() }
    let expanded = t.expand(path)
    try await resolve(t, [path], output: "", error: "realpath: \(expanded): \(why)\n", status: 1)
    // -q says nothing, but it is still a failure
    try await resolve(t, ["-q", path], output: "", error: "", status: 1)
  }

  @Test func theOthersAreStillResolved() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["@/link", "@/nonexist", "@/linksub"], output: t.path("real") + "\n" + t.path("real/sub") + "\n",
                      error: "realpath: \(t.root)/nonexist: No such file or directory\n", status: 1)
    try await resolve(t, ["-q", "@/nonexist", "@/link"], output: t.path("real") + "\n", error: "", status: 1)
  }

  @Test func emptyPath() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, [""], output: "", error: "realpath: : No such file or directory\n", status: 1)
    try await resolve(t, ["", "@/link"], output: t.path("real") + "\n", error: "realpath: : No such file or directory\n", status: 1)
  }

  @Test func namesWithOddCharacters() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    // characters that can't be seen are shown the way the C library shows them
    try await resolve(t, ["@/a\u{7}b"], output: "", error: "realpath: \(t.root)/a\\ab: No such file or directory\n", status: 1)
    try await resolve(t, ["@/a\u{1b}b"], output: "", error: "realpath: \(t.root)/a\\033b: No such file or directory\n", status: 1)
    try await resolve(t, ["@/é日"], output: "", error: "realpath: \(t.root)/é日: No such file or directory\n", status: 1)
  }

  // MARK: options

  @Test func quietDoesNotChangeTheOutput() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["-q", "@/link"], output: t.path("real") + "\n")
    try await resolve(t, ["-q"], in: "link", output: t.path("real") + "\n")
    try await resolve(t, ["-qq", "-q", "@/link"], output: t.path("real") + "\n")
  }

  @Test(arguments: [["-x"], ["-h"], ["-?"], ["--help"], ["-q", "-x"], ["-s", "real"], ["-E", "real"], ["-qx"]])
  func usageErrors(_ args: [String]) async throws {
    try await run(status: 1, output: "", error: Regex<Substring>(verbatim: Self.usageText), args: args)
  }

  @Test func doubleDashEndsTheOptions() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["--", "@/link"], output: t.path("real") + "\n")
    try await resolve(t, ["-q", "--", "-q"], output: "", error: "", status: 1)
    try await resolve(t, ["--", "-q"], output: "", error: "realpath: -q: No such file or directory\n", status: 1)
  }

  @Test func aLoneDashIsAPath() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["-"], output: "", error: "realpath: -: No such file or directory\n", status: 1)
  }

  /// A path after the first one that looks like an option is still a path.
  @Test func optionsAfterAPathAreAPaths() async throws {
    let t = RealpathTree()
    defer { t.remove() }
    try await resolve(t, ["@/link", "-q"], output: t.path("real") + "\n", error: "realpath: -q: No such file or directory\n", status: 1)
  }
}
