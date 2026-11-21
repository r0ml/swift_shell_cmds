
// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// The input files used by the hexdump and od tests, written once to a temporary directory.
/// The tests only read them.
enum HexdumpFixture {

  static let dir : FilePath = {
    let base = FilePath(Environment["TMPDIR"] ?? "/tmp")
    let d = base.appending("hexdump_fixture_\(getpid())")
    try? d.removeTree()
    try? d.createDirectory(FilePermissions(rawValue: 0o755))
    for (name, bytes) in files {
      guard let h = try? FileDescriptor.open(d.appending(name), .writeOnly, options: .create, permissions: FilePermissions(rawValue: 0o644)) else { continue }
      try? h.writeAllBytes(bytes)
      try? h.close()
    }
    return d
  }()

  static let files : [(String, [UInt8])] = [
    ("all.bin", (0...255).map { UInt8($0) }),
    ("text.txt", Array("Hello, world!\nThis is a test.\tTabs and \\ backslashes.\n\0NUL\u{7f}".utf8) + [0xff] + Array(" end\n".utf8)),
    ("rep.bin", Array(String(repeating: "ABCDEFGHIJKLMNOP", count: 10).utf8) + Array("tail".utf8)),     // repeated lines, for the '*' squeezing
    ("rep2.bin", [UInt8](repeating: 0, count: 64) + [UInt8(ascii: "x")] + [UInt8](repeating: 0, count: 64)),
    ("empty.bin", []),
    ("one.bin", [UInt8(ascii: "Z")]),
    ("seventeen.bin", (65...81).map { UInt8($0) }),
    ("utf8.txt", Array("h\u{e9}llo w\u{f6}rld \u{65e5}\u{672c}\u{8a9e} \u{2713}\n".utf8)),
    ("odd.bin", (1...7).map { UInt8($0) }),
    ("nine.bin", (1...9).map { UInt8($0) }),
    ("big.bin", (0..<5000).map { UInt8(($0 * 7 + 3) % 256) }),
    ("fmt1.fmt", Array("\"%07.7_Ax\\n\"\n\"%07.7_ax  \" 8/2 \"%04x \" \"\\n\"\n".utf8)),
    ("fmt2.fmt", Array("\"%08_ax: \" 16/1 \"%02x \" \"  |\" 16/1 \"%_p\" \"|\\n\"\n".utf8)),
    ("badfmt.fmt", Array("\"%\"\n".utf8)),
    ("comment.fmt", Array("# a comment\n\"%02x\\n\"\n".utf8)),
  ]
}
