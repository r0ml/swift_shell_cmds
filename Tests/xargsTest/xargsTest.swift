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

@Suite("xargs tests", .serialized) final class xargsTest : ShellTest {
  let cmd = "xargs"
  let suiteBundle = "shell_cmds_xargsTest"

//  REGRESSION_TEST(`normal', `xargs echo The <${SRCDIR}/regress.in')
  @Test func testNormal() async throws {
    let x = try fileContents("regress.normal.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "echo", "The")
  }
  
//  REGRESSION_TEST(`n2147483647', `xargs -n2147483647 <${SRCDIR}/regress.in')
  @Test func testN2147483647() async throws {
    let x = try fileContents("regress.n2147483647.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "-n2147483647")
  }

//  REGRESSION_TEST(`I', `xargs -I% echo The % % % %% % % <${SRCDIR}/regress.in')
  @Test func testI() async throws {
    let x = try fileContents("regress.I.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "-I", "%", "echo", "The", "%", "%", "%", "%%", "%", "%")
  }

  
//  REGRESSION_TEST(`J', `xargs -J% echo The % again. <${SRCDIR}/regress.in')
  @Test func testJ() async throws {
    let x = try fileContents("regress.J.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args:  "-J", "%", "echo", "The", "%", "again.")
  }

//  REGRESSION_TEST(`L', `xargs -L3 echo <${SRCDIR}/regress.in')
  @Test func testL() async throws {
    let x = try fileContents("regress.L.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "-L3", "echo")
  }

//  REGRESSION_TEST(`P1', `xargs -P1 echo <${SRCDIR}/regress.in')
  @Test func testP1() async throws {
    let x = try fileContents("regress.P1.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "-P1", "echo")
  }

//  REGRESSION_TEST(`R', `xargs -I% -R1 echo The % % % %% % % <${SRCDIR}/regress.in')
  @Test func testR() async throws {
    let x = try fileContents("regress.R.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "-I", "%", "-R1", "echo", "The", "%", "%", "%", "%%", "%", "%")
  }

//  REGRESSION_TEST(`R-1', `xargs -I% -R-1 echo The % % % %% % % <${SRCDIR}/regress.in')
  @Test func testR_1() async throws {
    let x = try fileContents("regress.R-1.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args: "-I", "%", "-R-1", "echo", "The", "%", "%", "%", "%%", "%", "%")
  }

//  REGRESSION_TEST(`n1', `xargs -n1 echo <${SRCDIR}/regress.in')
  @Test func testN1() async throws {
    let x = try fileContents("regress.n1.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args:  "-n1", "echo")
  }

//  REGRESSION_TEST(`n2', `xargs -n2 echo <${SRCDIR}/regress.in')
  @Test func testN2() async throws {
    let x = try fileContents("regress.n2.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args:  "-n2", "echo")
  }

//  REGRESSION_TEST(`n2P0',`xargs -n2 -P0 echo <${SRCDIR}/regress.in | sort')
  @Test func testN2P0() async throws {
    let x = try fileContents("regress.n2P0.out")
    let res = try fileContents("regress.in")

    try await run(withStdin: res, args: "-n2", "-P0", "echo") { po in
      //    let po = try await ShellProcess(cmd, "-n2", "-P0", "echo").run(res)
      let k = (po.string.dropLast().components(separatedBy: "\n").sorted().joined(separator: "\n"))+"\n"
      #expect( k == x )
    }
  }

//  REGRESSION_TEST(`n3', `xargs -n3 echo <${SRCDIR}/regress.in')
  @Test func testN3() async throws {
    let x = try fileContents("regress.n3.out")
    let res = try fileContents("regress.in")
    try await run(withStdin: res, output: x, args:  "-n3", "echo")
  }

//  REGRESSION_TEST(`0', `xargs -0 -n1 echo <${SRCDIR}/regress.0.in')
  @Test func test0() async throws {
    let x = try fileContents("regress.0.out")
    let res = try fileContents("regress.0.in")
    try await run(withStdin: res, output: x, args:  "-0", "-n1", "echo")
  }

//  REGRESSION_TEST(`0I', `xargs -0 -I% echo The % %% % <${SRCDIR}/regress.0.in')
  @Test func test0I() async throws {
    let x = try fileContents("regress.0I.out")
    let res = try fileContents("regress.0.in")
    try await run(withStdin: res, output: x, args: "-0", "-I%", "echo", "The", "%", "%%", "%")
  }

//  REGRESSION_TEST(`0J', `xargs -0 -J% echo The % again. <${SRCDIR}/regress.0.in')
  @Test func test0J() async throws {
    let x = try fileContents("regress.0J.out")
    let res = try fileContents("regress.0.in")
    try await run(withStdin: res, output: x, args: "-0", "-J%", "echo", "The", "%", "again.")
  }

//  REGRESSION_TEST(`0L', `xargs -0 -L2 echo <${SRCDIR}/regress.0.in')
  @Test func test0L() async throws {
    let x = try fileContents("regress.0L.out")
    let res = try fileContents("regress.0.in")
    try await run(withStdin: res, output: x, args: "-0", "-L2", "echo" )
  }

  // FIXME: when I forgot the "-" on "-P1" -- I didn't get the error I would have expected
  
//  REGRESSION_TEST(`0P1', `xargs -0 -P1 echo <${SRCDIR}/regress.0.in')
  @Test func test0P1() async throws {
    let x = try fileContents("regress.0P1.out")
    let res = try fileContents("regress.0.in")
    try await run(withStdin: res, output: x, args:  "-0", "-P1", "echo")
  }

  
//  REGRESSION_TEST(`quotes', `xargs -n1 echo <${SRCDIR}/regress.quotes.in')
  @Test func testQuotes() async throws {
    let x = try fileContents("regress.quotes.out")
    let res = try fileContents("regress.quotes.in")
    try await run(withStdin: res, output: x, args: "-n1", "echo")
  }
}
