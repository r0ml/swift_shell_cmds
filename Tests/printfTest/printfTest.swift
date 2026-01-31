/*
  The MIT License (MIT)
  Copyright © 2024 Robert (r0ml) Lefkowitz

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
  and associated documentation files (the “Software”), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
  OR OTHER DEALINGS IN THE SOFTWARE.
 */

import ShellTesting
import Darwin

@Suite(.serialized) struct printfTest : ShellTest {
  let cmd = "printf"
  let suiteBundle = "shell_cmds_printfTest"

  // REGRESSION_TEST(`b', `env printf "abc%b%b" "def\n" "\cghi"')
  @Test func test_b() async throws {
    let out = try fileContents("regress.b.out")
    try await run(output: out, args: "abc%b%b", "def\n", "\\cghi")
  }

  // REGRESSION_TEST(`d', `env printf "%d,%5d,%.5d,%0*d,%.*d\n" 123 123 123 5 123 5 123')
  @Test func test_d() async throws {
    let out = try fileContents("regress.d.out")
    try await run(output: out, args: "%d,%5d,%.5d,%0*d,%.*d\n", "123", "123", "123", "5", "123", "5", "123")
  }

  // REGRESSION_TEST(`f', `env printf "%f,%-8.3f,%f,%f\n" +42.25 -42.25 inf nan')
  @Test func test_f() async throws {
    let out = try fileContents("regress.f.out")
    try await run(output: out, args: "%f,%-8.3f,%f,%f\n", "+42.25", "-42.25", "inf", "nan")
  }

  // REGRESSION_TEST(`l1', `LC_ALL=en_US.ISO8859-1 env printf "%d\n" $(env printf \"\\344)')
  // The implementation will use ISOLatin1 (ISO8859-1) for characters in the 0-255 range -- but will use
  // the first unicode scalar of the composite for all others.
  // This passes this test, but it is unclear that this behavior is correct for all characters
  @Test(  // .disabled("arguments get interpreted with utf8 -- the \\344 character gets translated to two scalars")
  ) func test_l1() async throws {
    Darwin.setenv("LC_ALL","en.US.ISO8859-1", 1)
    try await run(args: "\"\\344") { po1 in
      //    let po1 = try await ShellProcess(cmd, "\"\\344").run()
      try await run(args: "%d\n", po1.string) { po2 in
        //      let po2 = try await ShellProcess(cmd, "%d\n", po1.string).run()
        let out = try fileContents("regress.l1.out")
        #expect(po2.string == out)
      }
    }
  }

  // REGRESSION_TEST(`l2', `LC_ALL=en_US.UTF-8 env printf "%d\n" $(env printf \"\\303\\244)')
  // FIXME: The conversion on the way in is problematic
  @Test(.disabled("Command line arguments are always parsed as UTF-8, so the \\303\\244 sequence is interpreted as two characters"))
  func test_l2() async throws {
    Darwin.setenv("LC_ALL", "en.US.UTF-8", 1)
    //    let po1 = try await ShellProcess(cmd, "\"\\303\\244").run()
    try await run(args: "\"\\303\\244") { po1 in
      //    let j3 = "\"\u{195}\u{164}"
      try await run(args: "%d\n", po1.string) { po2 in
        let out = try fileContents("regress.l2.out")
        #expect(po2.string == out)
      }
    }
  }

 // REGRESSION_TEST(`m1', `env printf "%c%%%d\0\045\n" abc \"abc')
  @Test func test_m1() async throws {
    let out = try fileContents("regress.m1.out")
    try await run(output: out, args: "%c%%%d\\0\\045\n", "abc", "\"abc")
  }

 // REGRESSION_TEST(`m2', `env printf "abc\n\cdef"')
  @Test func test_m2() async throws {
    let out = try fileContents("regress.m2.out")
    try await run(output: out, args: "abc\\n\\cdef")
  }

 // REGRESSION_TEST(`m3', `env printf "%%%s\n" abc def ghi jkl')
  @Test func test_m3() async throws {
    let out = try fileContents("regress.m3.out")
    try await run(output: out, args: "%%%s\\n", "abc", "def", "ghi", "jkl")
  }

 // REGRESSION_TEST(`m4', `env printf "%d,%f,%c,%s\n"')
  @Test func test_m4() async throws {
    let out = try fileContents("regress.m4.out")
    try await run(output: out, args: "%d,%f,%c,%s\n")
  }

 // REGRESSION_TEST(`m5', `env printf -- "-d\n"')
  @Test func test_m5() async throws {
    let out = try fileContents("regress.m5.out")
    try await run(output: out, args: "--", "-d\n")
  }

 // REGRESSION_TEST(`s', `env printf "%.3s,%-5s\n" abcd abc')
  @Test func test_s() async throws {
    let out = try fileContents("regress.s.out")
    try await run(output: out, args: "%.3s,%-5s\n", "abcd", "abc")
  }

 // REGRESSION_TEST('zero', `env printf "%u%u\n" 15')
  @Test func test_zero1() async throws {
    let out = try fileContents("regress.zero.out")
    try await run(output: out, args: "%u%u\n", "15")
  }

 // REGRESSION_TEST('zero', `env printf "%d%d\n" 15')
  @Test func test_zero2() async throws {
    let out = try fileContents("regress.zero.out")
    try await run(output: out, args: "%d%d\n", "15")
  }

 // REGRESSION_TEST('zero', `env printf "%d%u\n" 15')
  @Test func test_zero3() async throws {
    let out = try fileContents("regress.zero.out")
    try await run(output: out, args: "%d%u\n", "15")
  }

 // REGRESSION_TEST('zero', `env printf "%u%d\n" 15')
  @Test func test_zero4() async throws {
    let out = try fileContents("regress.zero.out")
    try await run(output: out, args: "%u%d\n", "15")
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%1\$*s" 1 1 2>&1')
  @Test func test_missingpos1() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%1$*s", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%*1\$s" 1 1 2>&1')
  @Test func test_missingpos2() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run( args: "%*1$s", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%1\$*.*s" 1 1 1 2>&1')
  @Test func test_missingpos3() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%1$*.*s", "1", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%*1\$.*s" 1 1 1 2>&1')
  @Test func test_missiingpos4() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%*1$.*s", "1", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%*.*1\$s" 1 1 1 2>&1')
  @Test func test_missingpos5() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%*.*1$s", "1", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%1\$*2\$.*s" 1 1 1 2>&1')
  @Test func test_missingpos6() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%1$*2$.*s", "1", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%*1\$.*2\$s" 1 1 1 2>&1')
  @Test func test_missingpos7() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%*1$.*2$s", "1", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`missingpos1', `env printf "%1\$*.*2\$s" 1 1 1 2>&1')
  @Test func test_missingpos8() async throws {
    let out = try fileContents("regress.missingpos1.out")
    try await run(args: "%1$*.*2$s", "1", "1", "1") { po in
      #expect( (po.string + po.error) == out)
    }
  }

 // REGRESSION_TEST(`bwidth', `env printf "%8.2b" "a\nb\n"')
  @Test func test_bwidth() async throws {
    let out = try fileContents("regress.bwidth.out")
    try await run( args: "%8.2b", "a\nb\n") { po in
      #expect( (po.string + po.error) == out)
    }
  }

  
  // ====================================================================
  
  @Test func test_r1() async throws {
    try await run(output: "111", args: "%1$s", "1", "1", "1")
  }

  @Test func test_r2() async throws {
    try await run(output: "1", args: "%2$s", "1", "1", "1")
  }

  @Test func test_r3() async throws {
    let ex = "a%97\0%\n"
    try await run(output: ex, args: "%c%%%d\\0\\045\\n", "abc", "\"abc")
  }


}
