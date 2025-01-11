
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024
// from a file containing the following notice:

// Submitted by Edwin Groothuis <edwin@FreeBSD.org>

import ShellTesting

@Suite class dateTest : ShellTest {
  let cmd = "date"
  let suite = "shell_cmds_dateTesting"
  
/*
  These two date/times have been chosen carefully -- they
  create both the single digit and double/multidigit version of
  the values.

  To create a new one, make sure you are using the UTC timezone!
 */

  static let TEST1 = 3222243 // 1970-02-07 07:04:03
  static let TEST2 = 1005600000 // 2001-11-12 21:11:12

  @Test(.serialized, arguments: [("A", "Saturday", "Monday" ), ("a", "Sat", "Mon" ), ("B", "February", "November" ), ("b", "Feb", "Nov" ),
                    ("C", "19", "20" ), ("c", "Sat Feb  7 07:04:03 1970", "Mon Nov 12 21:20:00 2001" ), ("D", "02/07/70", "11/12/01" ),
                    ("d", "07", "12" ), ("e", " 7", "12" ), ("F", "1970-02-07", "2001-11-12" ), ("G", "1970", "2001" ),
                    ("g", "70", "01" ), ("H", "07", "21" ), ("h", "Feb", "Nov" ), ("I", "07", "09" ), ("j", "038", "316" ),
                    ("k", " 7", "21" ), ("l", " 7", " 9" ), ("M", "04", "20" ), ("m", "02", "11" ), ("p", "AM", "PM" ),
                    ("R", "07:04", "21:20" ), ("r", "07:04:03 AM", "09:20:00 PM" ), ("S", "03", "00" ), ("s", "\(TEST1)", "\(TEST2)" ),
                    ("U", "05", "45" ), ("u", "6", "1" ), ("V", "06", "46" ), ("v", " 7-Feb-1970", "12-Nov-2001" ),  ("W", "05", "46" ),
                    ("w", "6", "1" ), ("X", "07:04:03", "21:20:00" ), ("x", "02/07/70", "11/12/01" ), ("Y", "1970", "2001" ),
                    ("y", "70", "01" ), ("Z", "UTC", "UTC" ), ("z", "+0000", "+0000" ), ("%", "%", "%" ),
                    ("+","Sat Feb  7 07:04:03 UTC 1970", "Mon Nov 12 21:20:00 UTC 2001" )
                   ])
  func testFormat(_ opt : String, _ a : String, _ b : String) async throws {
    try await run(output: "\(a)\n", args: "-u", "-r", "\(Self.TEST1)", "+%\(opt)", env: ["LC_ALL":"default"] )
    try await run(output: "\(b)\n", args: "-u", "-r", "\(Self.TEST2)", "+%\(opt)", env: ["LC_ALL":"default"] )
  }

  @Test(arguments: [("", "1970-02-07", "2001-11-12" ), ("date", "1970-02-07", "2001-11-12" ), ("hours", "1970-02-07T07+00:00", "2001-11-12T21+00:00" ),
                    ("minutes", "1970-02-07T07:04+00:00", "2001-11-12T21:20+00:00" ), ("seconds", "1970-02-07T07:04:03+00:00", "2001-11-12T21:20:00+00:00" )
                   ])
  func testIso8601(_ arg : String, _ a : String, _ b : String) async throws {
    try await run(output: "\(a)\n", args: "-u", "-r", "\(Self.TEST1)", "-I\(arg)" )
    try await run(output: "\(b)\n", args: "-u", "-r", "\(Self.TEST2)", "-I\(arg)" )
  }
  

}
