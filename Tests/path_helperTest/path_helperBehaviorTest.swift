// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// A made-up root directory, with /etc/paths and so on inside it, for path_helper to read through PATH_HELPER_ROOT.
final class FakeRoot {
  let path: String
  private var made = [String]()

  init() {
    var template = Array("/tmp/pathhelpertestXXXXXX".utf8CString)
    path = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
  }

  func directory(_ name: String) {
    var current = path
    for part in name.split(separator: "/") {
      current += "/" + part
      if mkdir(current, 0o755) == 0 { made.append(current) }
    }
  }

  /// Makes a file (and the directories above it) holding `bytes`.
  func file(_ name: String, _ bytes: [UInt8]) {
    if let slash = name.lastIndex(of: "/") {
      directory(String(name[..<slash]))
    }
    let full = path + name
    let fd = open(full, O_CREAT | O_WRONLY | O_TRUNC, 0o644)
    _ = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
    close(fd)
    made.append(full)
  }

  func file(_ name: String, _ text: String) { file(name, Array(text.utf8)) }

  func symlink(_ name: String, to target: String) {
    directory(String(name[..<name.lastIndex(of: "/")!]))
    Darwin.symlink(target, path + name)
    made.append(path + name)
  }

  func remove() {
    for item in made.reversed() {
      if unlink(item) != 0 { rmdir(item) }
    }
    rmdir(path)
  }
}

extension path_helperTest {

  /// The lines path_helper writes for the sh style.
  static func sh(_ path: String, manpath: String? = nil) -> String {
    "PATH=\"\(path)\"; export PATH;\n" + (manpath.map { "MANPATH=\"\($0)\"; export MANPATH;\n" } ?? "")
  }

  func check(_ root: FakeRoot, env: [String: String], args: [String] = [], output: String, status: Int = 0) async throws {
    var environment = env
    environment["PATH_HELPER_ROOT"] = root.path
    try await run(status: status, output: output, args: args, env: environment)
  }

  // MARK: PATH

  @Test func defaultsComeFirstThenAddOnsThenWhatWasThere() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\nb\n")
    r.file("/etc/paths.d/x", "c\nd\n")
    try await check(r, env: ["PATH": "e:f"], output: Self.sh("a:b:c:d:e:f"))
  }

  @Test func repeatedElementsAreKeptOnce() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\nb\na\nb\n")
    r.file("/etc/paths.d/x", "b\nc\nc\n")
    try await check(r, env: ["PATH": "c:a:d:d"], output: Self.sh("a:b:c:d"))
  }

  /// Only whole elements count as being there already.
  @Test func substringsAreNotElements() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "ab\n")
    try await check(r, env: ["PATH": "a:b:aab:abc"], output: Self.sh("ab:a:b:aab:abc"))
    let s = FakeRoot()
    defer { s.remove() }
    s.file("/etc/paths", "a\n")
    try await check(s, env: ["PATH": "ba:ab:xa:ax"], output: Self.sh("a:ba:ab:xa:ax"))
  }

  @Test func emptyElementsOfThePathAreDropped() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\n")
    try await check(r, env: ["PATH": "a::b:"], output: Self.sh("a:b"))
    try await check(r, env: ["PATH": ":::"], output: Self.sh("a"))
  }

  @Test func nothingAtAll() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    try await check(r, env: ["PATH": ""], output: Self.sh(""))
    try await check(r, env: ["PATH": "p:q"], output: Self.sh("p:q"))
  }

  @Test func missingFilesAndDirectories() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths.d/only", "o\n")
    try await check(r, env: ["PATH": "p"], output: Self.sh("o:p"))
    let s = FakeRoot()
    defer { s.remove() }
    s.file("/etc/paths", "a\n")
    try await check(s, env: ["PATH": "p"], output: Self.sh("a:p"))
  }

  // MARK: reading the files

  @Test(arguments: [("a\nb", "a:b"), ("a\n\n\nb\n", "a:b"), ("a b\nc\td\n", "a b:c\td"), ("  \n", "  "),
                    ("a:b\nc\n", "a:b:c"), ("a\r\nb\r\n", "a\r:b\r"), ("é\n日本\n", "é:日本"), ("\n\n\n", ""), ("", "")])
  func linesOfAFile(_ text: String, _ expected: String) async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", text)
    try await check(r, env: ["PATH": ""], output: Self.sh(expected))
  }

  /// Quotes and dollar signs are made safe for the double quotes around the value.
  @Test func characterThatNeedAProtection() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\"b\n$HOME\nc'd\n`x`\n\\e\n")
    try await check(r, env: ["PATH": ""], output: Self.sh("a\\\"b:\\$HOME:c\\'d:`x`:\\e"))
  }

  @Test func aNulEndsALine() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", [0x61, 0, 0x62, 0x0a, 0x63, 0x0a])
    try await check(r, env: ["PATH": ""], output: Self.sh("a:c"))
  }

  /// A path is bytes: what isn't valid UTF-8 is passed through unchanged.
  @Test func bytesThatAreNotText() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", [0xff, 0xfe, 0x0a, 0x6f, 0x6b, 0x0a])
    var environment = ["PATH": "", "PATH_HELPER_ROOT": r.path]
    environment["MANPATH"] = nil
    try await run(output: Array("PATH=\"".utf8) + [0xff, 0xfe] + Array(":ok\"; export PATH;\n".utf8), env: environment)
  }

  @Test func longLines() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    let long = String(repeating: "a", count: 70000)
    r.file("/etc/paths", long + "\nz\n")
    try await check(r, env: ["PATH": ""], output: Self.sh(long + ":z"))
  }

  @Test func manyElementsAndALongPath() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    let names = (0..<3000).map { "p\($0)" }
    r.file("/etc/paths", names.joined(separator: "\n") + "\n")
    try await check(r, env: ["PATH": String(repeating: "x", count: 20000)], output: Self.sh(names.joined(separator: ":") + ":" + String(repeating: "x", count: 20000)))
  }

  // MARK: the directory

  @Test func onlyRegularFilesOneLevelDeepAreRead() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\n")
    r.file("/etc/paths.d/real", "real\n")
    r.file("/etc/paths.d/sub/inner", "deep\n")
    r.file("/etc/paths.d/.hidden", "h\n")
    r.file("/etc/paths.d/empty", "")
    r.file("/etc/paths.d/vis", "v\n")
    r.symlink("/etc/paths.d/link", to: "real")
    r.symlink("/etc/paths.d/dangling", to: "nowhere")
    // symbolic links are not followed, and sub-directories are not entered; hidden files are read
    try await check(r, env: ["PATH": ""], output: Self.sh("a:h:real:v"))
  }

  /// Files are read in order: a leading number counts as a number, and the rest of the name decides ties.
  @Test func filesAreReadInOrder() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\nb\n")
    r.file("/etc/paths.d/a", "z\n")
    r.file("/etc/paths.d/1000", "y\n")
    r.file("/etc/paths.d/0400-b", "x\n")
    r.file("/etc/paths.d/400-a", "w\n")
    r.file("/etc/paths.d/70def", "d\ne\nf\n")
    r.file("/etc/paths.d/9", "c\n")
    try await check(r, env: ["PATH": "g:h"], output: Self.sh("a:b:c:d:e:f:w:x:y:z:g:h"))
  }

  @Test func orderOfNumbersAndNames() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths.d/10-b", "b\n")
    r.file("/etc/paths.d/2-a", "a2\n")
    r.file("/etc/paths.d/10-a", "a10\n")
    r.file("/etc/paths.d/02-x", "x2\n")
    r.file("/etc/paths.d/002", "z\n")
    try await check(r, env: ["PATH": ""], output: Self.sh("z:a2:x2:a10:b"))
  }

  @Test func orderOfNamesWithoutNumbers() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths.d/B", "B\n")
    r.file("/etc/paths.d/a", "lowera\n")
    r.file("/etc/paths.d/_u", "u\n")
    r.file("/etc/paths.d/Z", "Z\n")
    try await check(r, env: ["PATH": ""], output: Self.sh("B:Z:u:lowera"))
  }

  @Test func orderOfNumbersThatTie() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths.d/1a", "1a\n")
    r.file("/etc/paths.d/1", "1\n")
    r.file("/etc/paths.d/1b", "1b\n")
    r.file("/etc/paths.d/2", "2\n")
    r.file("/etc/paths.d/02a", "2a\n")
    try await check(r, env: ["PATH": ""], output: Self.sh("1:1a:1b:2:2a"))
  }

  @Test func numbersTooBigForAnInteger() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\n")
    r.file("/etc/paths.d/99999999999999999999", "big\n")
    r.file("/etc/paths.d/1", "one\n")
    try await check(r, env: ["PATH": ""], output: Self.sh("a:one:big"))
  }

  // MARK: MANPATH

  @Test func manpathIsOnlyDoneWhenItIsSet() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/manpaths", "m1\n")
    try await check(r, env: ["PATH": ""], output: Self.sh(""))
    try await check(r, env: ["PATH": "", "MANPATH": ""], output: Self.sh("", manpath: "m1:"))
  }

  @Test func manpathCombinesLikePath() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/manpaths", "m1\nm2\n")
    r.file("/etc/manpaths.d/x", "m3\n")
    r.file("/etc/paths", "a\n")
    try await check(r, env: ["PATH": "", "MANPATH": "z:m1"], output: Self.sh("a", manpath: "m1:m2:m3:z:"))
  }

  /// The value always ends with a colon, so that the system's default man path is still searched.
  @Test(arguments: [("", ":"), ("c:d", "c:d:"), (":m2:", "m2:")])
  func manpathEndsWithAColon(_ manpath: String, _ expected: String) async throws {
    let r = FakeRoot()
    defer { r.remove() }
    try await check(r, env: ["PATH": "", "MANPATH": manpath], output: Self.sh("", manpath: expected))
  }

  // MARK: shells

  @Test(arguments: [("/bin/zsh", false), ("/bin/bash", false), ("/bin/sh", false), ("", false), ("/bin/csh", true),
                    ("/bin/tcsh", true), ("/usr/local/bin/mycsh", true), ("/bin/cshx", true), ("csh", true)])
  func styleFollowsTheShell(_ shell: String, _ csh: Bool) async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\nb\n")
    r.file("/etc/manpaths", "m\n")
    let expected = csh ? "setenv PATH \"a:b:p\";\nsetenv MANPATH \"m:q\":;\n"
                       : Self.sh("a:b:p", manpath: "m:q:")
    try await check(r, env: ["PATH": "p", "MANPATH": "q", "SHELL": shell], output: expected)
  }

  @Test func cshStyleWithoutManpath() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\n")
    try await check(r, env: ["PATH": "p", "SHELL": "/bin/tcsh"], output: "setenv PATH \"a:p\";\n")
  }

  @Test(arguments: [(["-c"], true), (["-s"], false), (["-c", "-s"], false), (["-s", "-c"], true), (["-cs"], false), (["-sc"], true),
                    (["-c", "-c"], true)])
  func optionsChooseTheStyle(_ args: [String], _ csh: Bool) async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\n")
    let expected = csh ? "setenv PATH \"a:p\";\n" : Self.sh("a:p")
    // whatever the shell
    try await check(r, env: ["PATH": "p", "SHELL": "/bin/zsh"], args: args, output: expected)
    try await check(r, env: ["PATH": "p", "SHELL": "/bin/tcsh"], args: args, output: expected)
  }

  /// "--" is no option: the shell still decides.
  @Test func doubleDashChoosesNothing() async throws {
    let r = FakeRoot()
    defer { r.remove() }
    r.file("/etc/paths", "a\n")
    try await check(r, env: ["PATH": "p", "SHELL": "/bin/zsh"], args: ["--"], output: Self.sh("a:p"))
    try await check(r, env: ["PATH": "p", "SHELL": "/bin/tcsh"], args: ["--"], output: "setenv PATH \"a:p\";\n")
  }

  @Test(arguments: [(["-x"], "illegal option -- x"), (["-h"], "illegal option -- h")])
  func unknownOptions(_ args: [String], _ message: String) async throws {
    try await run(status: 1, error: Regex<Substring>(verbatim: "path_helper: \(message)\nusage: path_helper [-c | -s]"), args: args)
  }

  @Test(arguments: [["x"], ["-s", "x"], ["--", "-s"], ["a", "b"]])
  func operandsAreNotAllowed(_ args: [String]) async throws {
    try await run(status: 1, error: Regex<Substring>(verbatim: "usage: path_helper [-c | -s]"), args: args)
  }
}
