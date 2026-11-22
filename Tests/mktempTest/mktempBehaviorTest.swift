// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A directory for a test to make temporary names in.
final class TemplateDirectory {
  let path: String

  init() {
    var template = Array("/tmp/mktemptestXXXXXX".utf8CString)
    path = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  var directory: FilePath { FilePath(path) }

  /// What is in the directory, as (name, mode, is a directory) sorted by name.
  func contents() -> [(name: String, mode: mode_t, isDirectory: Bool)] {
    guard let d = opendir(path) else { return [] }
    defer { closedir(d) }
    var found = [(name: String, mode: mode_t, isDirectory: Bool)]()
    while let e = readdir(d) {
      let name = withUnsafePointer(to: &e.pointee.d_name) {
        $0.withMemoryRebound(to: CChar.self, capacity: Int(e.pointee.d_namlen) + 1) { String(cString: $0) }
      }
      if name == "." || name == ".." { continue }
      var st = stat()
      lstat(path + "/" + name, &st)
      found.append((name, st.st_mode & 0o7777, (st.st_mode & S_IFMT) == S_IFDIR))
    }
    return found.sorted { $0.name < $1.name }
  }

  /// Removes what the test made (and the directory), leaving anything else alone.
  func remove() {
    for item in contents() {
      if item.isDirectory { rmdir(path + "/" + item.name) } else { unlink(path + "/" + item.name) }
    }
    rmdir(path)
  }
}

extension mktempTest {

  static let usageLines = """
    usage: mktemp [-d] [-p tmpdir] [-q] [-t prefix] [-u] template ...
           mktemp [-d] [-p tmpdir] [-q] [-u] -t prefix 

    """

  /// The user's temporary directory, which ends in a slash.
  static let userTempDirectory : String = {
    var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
    confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count)
    return String(cString: buf)
  }()

  static let alphanumerics = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

  /// Whether `name` is `stem` followed by `count` characters that could have replaced X.
  static func isGenerated(_ name: Substring, stem: String, count: Int) -> Bool {
    name.hasPrefix(stem) && name.dropFirst(stem.count).count == count && name.dropFirst(stem.count).allSatisfy(alphanumerics.contains)
  }

  /// `text` with the characters that mean something in a regular expression escaped.
  static func escaped(_ text: String) -> String {
    String(text.flatMap { "\\^$.|?*+()[]{}".contains($0) ? ["\\", $0] : [$0] })
  }

  func lines(_ po: DarwinProcess.Output) throws -> [String] {
    try po.string(encoded: .utf8).split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
  }

  // MARK: templates

  @Test(arguments: [("foo", 6), ("foo.", 6), ("foo", 1), ("foo", 3), ("", 6), ("foo", 16), ("a.", 12)])
  func fileFromATemplate(_ stem: String, _ count: Int) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: d.path + "/" + stem + String(repeating: "X", count: count)) { po in
      let out = try self.lines(po)
      #expect(out.count == 1)
      #expect(out[0].hasPrefix(d.path + "/"))
      #expect(Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: stem, count: count))
      #expect(po.error.isEmpty)
    }
    let found = d.contents()
    #expect(found.count == 1)
    #expect(found.first?.mode == 0o600)
    #expect(found.first?.isDirectory == false)
  }

  @Test func directoryFromATemplate() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-d", d.path + "/fooXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "foo", count: 6))
    }
    #expect(d.contents().map(\.mode) == [0o700])
    #expect(d.contents().map(\.isDirectory) == [true])
  }

  @Test func theFileNameIsDifferentEachTime() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    for _ in 0..<5 {
      try await run(args: d.path + "/aXXXXXX")
    }
    #expect(Set(d.contents().map(\.name)).count == 5)
  }

  @Test func manyTemplatesInOneRun() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: d.path + "/aXXXXXX", d.path + "/bXXXXXX", d.path + "/cXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 3)
      for (line, stem) in zip(out, ["a", "b", "c"]) {
        #expect(Self.isGenerated(line.dropFirst(d.path.count + 1), stem: stem, count: 6))
      }
    }
    #expect(d.contents().count == 3)
  }

  @Test(arguments: ["-u", "-du", "-ud", "--dry-run"])
  func dryRunLeavesNothing(_ flag: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: flag, d.path + "/fooXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "foo", count: 6))
    }
    #expect(d.contents().isEmpty)
  }

  @Test(arguments: ["-d", "--directory", "-dq"])
  func directoryOptions(_ flag: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: flag, d.path + "/dXXXXXX")
    #expect(d.contents().map(\.isDirectory) == [true])
  }

  /// Only trailing Xs are replaced; a name without any is used as it is.
  @Test(arguments: ["foo", "fooXbar", "XXXXXXfoo"])
  func noTrailingXs(_ name: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(output: d.path + "/" + name + "\n", args: d.path + "/" + name)
    #expect(d.contents().map(\.name) == [name])
    // and then it exists
    try await run(status: 1, error: "mktemp: mkstemp failed on \(d.path)/\(name): File exists\n", args: d.path + "/" + name)
  }

  @Test func templatesAreMadeInOrderAndFailuresDoNotStopTheRest() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(status: 1, error: /mktemp: mkstemp failed on .*nonexistent\/foo[A-Za-z0-9]{6}: No such file or directory\n/,
                  args: d.path + "/aXXXXXX", d.path + "/nonexistent/fooXXXXXX", d.path + "/bXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 2)
      #expect(out[0].hasPrefix(d.path + "/a") && out[1].hasPrefix(d.path + "/b"))
    }
    #expect(d.contents().count == 2)
  }

  @Test(arguments: [(false, "mkstemp"), (true, "mkdtemp")])
  func failureMessageNamesTheCall(_ directory: Bool, _ call: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(status: 1, output: "",
                  error: try Regex("mktemp: \(call) failed on \(Self.escaped(d.path))/nonexistent/foo[A-Za-z0-9]{6}: No such file or directory\n"),
                  args: (directory ? ["-d"] : []) + [d.path + "/nonexistent/fooXXXXXX"])
  }

  /// The name that was tried is shown with the Xs replaced.
  @Test func failureShowsTheGeneratedName() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(status: 1, error: /failed on .*\/nonexistent\/foo[A-Za-z0-9]{6}:/, args: d.path + "/nonexistent/fooXXXXXX")
  }

  @Test(arguments: [[String](), ["-d"]])
  func quietFailure(_ extra: [String]) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(status: 1, output: "", error: "", args: ["-q"] + extra + [d.path + "/nonexistent/fooXXXXXX"])
  }

  @Test func quietDoesNotHideTheOutput() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-q", d.path + "/aXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 1)
    }
  }

  // MARK: -p

  @Test func tmpdirOptionPrefixesTemplates() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-p", d.path, "aXXXXXX", "b", "c.d") { po in
      let out = try self.lines(po)
      #expect(out.count == 3)
      #expect(Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "a", count: 6))
      #expect(out[1] == d.path + "/b")
      #expect(out[2] == d.path + "/c.d")
    }
    #expect(d.contents().count == 3)
  }

  @Test(arguments: ["-p", "--tmpdir="])
  func tmpdirOptionForms(_ form: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    let args = form == "-p" ? ["-p", d.path, "x"] : ["--tmpdir=" + d.path, "x"]
    try await run(output: d.path + "/x\n", args: args)
    #expect(d.contents().map(\.name) == ["x"])
  }

  @Test func attachedTmpdirArgument() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(output: d.path + "/x\n", args: "-p" + d.path, "x")
  }

  /// A template is joined to the directory with exactly one slash added.
  @Test func slashesAreNotCleanedUp() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(output: d.path + "//x\n", args: "-p", d.path + "/", "x")
    try await run(output: d.path + "///y\n", args: "-p", d.path + "//", "y")
  }

  @Test func tmpdirWithNoTemplate() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-p", d.path) { po in
      let out = try self.lines(po)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "tmp.", count: 10))
    }
    #expect(d.contents().count == 1)
    #expect(d.contents().first?.isDirectory == false)
  }

  @Test func tmpdirWithNoTemplateAndD() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-d", "-p", d.path) { po in
      let out = try self.lines(po)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "tmp.", count: 10))
    }
    #expect(d.contents().map(\.isDirectory) == [true])
  }

  /// With -t the generated name is prefix.XXXXXXXXXX in the tmpdir.
  @Test(arguments: ["", "/", "//"])
  func tmpdirWithPrefix(_ slashes: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-p", d.path + slashes, "-t", "foo") { po in
      let out = try self.lines(po)
      // the tmpdir is used as it is; a slash is added only if it doesn't end in one
      let dir = d.path + (slashes.isEmpty ? "/" : slashes)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(dir.count), stem: "foo.", count: 10))
    }
    #expect(d.contents().count == 1)
  }

  /// With -t the templates aren't relative to the tmpdir: they are used as they are.
  @Test func prefixAndTemplatesTogether() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-p", d.path, "-t", "foo", "x", "yXXXXXX", cd: d.directory) { po in
      let out = try self.lines(po)
      #expect(out.count == 3)
      #expect(Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "foo.", count: 10))
      #expect(out[1] == "x")
      #expect(Self.isGenerated(out[2].dropFirst(0), stem: "y", count: 6))
    }
    #expect(d.contents().count == 3)
  }

  /// An empty or missing directory means the environment's.
  @Test(arguments: [["-p", ""], ["--tmpdir"], ["--tmpdir="]])
  func emptyTmpdirUsesTheEnvironment(_ opts: [String]) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: opts + ["x"], env: ["TMPDIR": d.path]) { po in
      let out = try self.lines(po)
      #expect(out == [d.path + "/x"])
    }
    try await run(args: opts, env: ["TMPDIR": d.path]) { po in
      let out = try self.lines(po)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "tmp.", count: 10))
    }
    #expect(d.contents().count == 2)
  }

  /// "--tmpdir" takes its argument only after an equals sign: otherwise the next word is a template.
  @Test func longTmpdirOptionTakesAnArgumentOnlyWithEquals() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    // the directory name is taken as a template, and it has no trailing X: it is created as it is, under TMPDIR
    try await run(status: 1, error: "mktemp: mkstemp failed on \(d.path)/\(d.path): No such file or directory\n",
                  args: "--tmpdir", d.path, env: ["TMPDIR": d.path])
  }

  @Test func theLastTmpdirWins() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(output: d.path + "/y\n", args: "-p", d.path + "/nonexistent", "-p", d.path, "y")
  }

  @Test func missingTmpdir() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(status: 1, error: Regex<Substring>(verbatim: "mkstemp failed on \(d.path)/nonexistent/x: No such file or directory\n"),
                  args: "-p", d.path + "/nonexistent", "x")
    try await run(status: 1, output: "", error: "", args: "-q", "-p", d.path + "/nonexistent", "x")
    try await run(status: 1, error: /mkstemp failed on .*\/nonexistent\/foo\.[A-Za-z0-9]{10}: No such file or directory\n/,
                  args: "-p", d.path + "/nonexistent", "-t", "foo")
  }

  // MARK: -t and the defaults

  /// Without -p, the user's temporary directory is used, and TMPDIR doesn't matter.
  @Test(arguments: [["-t", "kat"], ["-tkat"]])
  func prefixInTheUserTempDirectory(_ opts: [String]) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: opts + ["-u"], env: ["TMPDIR": d.path]) { po in
      let out = try self.lines(po)
      #expect(out.count == 1)
      #expect(out[0].hasPrefix(Self.userTempDirectory))
      #expect(Self.isGenerated(out[0].dropFirst(Self.userTempDirectory.count), stem: "kat.", count: 10))
    }
    #expect(d.contents().isEmpty)
  }

  @Test func prefixCreatesTheFile() async throws {
    try await run(args: "-t", "katmade") { po in
      let name = try self.lines(po)[0]
      defer { unlink(name) }
      var st = stat()
      #expect(stat(name, &st) == 0)
      #expect(st.st_mode & 0o7777 == 0o600)
      #expect(Self.isGenerated(name.dropFirst(Self.userTempDirectory.count), stem: "katmade.", count: 10))
    }
  }

  @Test(arguments: [[String](), ["-d"], ["-q"]])
  func noArgumentsMeansPrefixTmp(_ opts: [String]) async throws {
    try await run(args: opts) { po in
      let name = try self.lines(po)[0]
      defer { if opts.contains("-d") { rmdir(name) } else { unlink(name) } }
      #expect(Self.isGenerated(name.dropFirst(Self.userTempDirectory.count), stem: "tmp.", count: 10))
      var st = stat()
      #expect(stat(name, &st) == 0)
      #expect((st.st_mode & S_IFMT) == (opts.contains("-d") ? S_IFDIR : S_IFREG))
    }
  }

  @Test func prefixMayHoldSlashesButNotMakeDirectories() async throws {
    try await run(status: 1, error: /mktemp: mkstemp failed on .*\/foo\/bar\.[A-Za-z0-9]{10}: No such file or directory\n/,
                  args: "-t", "foo/bar")
  }

  @Test func lastPrefixWins() async throws {
    try await run(args: "-u", "-t", "foo", "-t", "bar") { po in
      let out = try self.lines(po)
      #expect(Self.isGenerated(out[0].dropFirst(Self.userTempDirectory.count), stem: "bar.", count: 10))
    }
  }

  @Test func prefixAlsoMakesTheGivenTemplates() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-u", "-t", "foo", d.path + "/aXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 2)
      #expect(Self.isGenerated(out[0].dropFirst(Self.userTempDirectory.count), stem: "foo.", count: 10))
      #expect(Self.isGenerated(out[1].dropFirst(d.path.count + 1), stem: "a", count: 6))
    }
  }

  // MARK: usage

  @Test(arguments: [(["-t"], "option requires an argument -- t"), (["-p"], "option requires an argument -- p"),
                    (["-x"], "invalid option -- x"), (["-d", "-x"], "invalid option -- x"), (["-h"], "invalid option -- h"),
                    (["-p", "/tmp", "-t"], "option requires an argument -- t"),
                    (["--foo"], "unrecognized option `--foo'")])
  func usageErrors(_ args: [String], _ message: String) async throws {
    try await run(status: 1, output: "", error: "mktemp: \(message)\n" + Self.usageLines, args: args)
  }

  @Test(arguments: ["--", "-q", "-u", "-d"])
  func optionsAfterTemplatesAreStillOptions(_ flag: String) async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    if flag == "--" {
      try await run(args: d.path + "/aXXXXXX", flag)
      #expect(d.contents().count == 1)
    } else {
      try await run(args: d.path + "/aXXXXXX", flag)
    }
  }

  @Test func doubleDashEndsOptions() async throws {
    let d = TemplateDirectory()
    defer { d.remove() }
    try await run(args: "-p", d.path, "--", "-aXXXXXX") { po in
      let out = try self.lines(po)
      #expect(out.count == 1 && Self.isGenerated(out[0].dropFirst(d.path.count + 1), stem: "-a", count: 6))
    }
  }
}
