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

import Testing
import testSupport

@Suite("xargs tests") final class xargsTest {

//  REGRESSION_TEST(`normal', `xargs echo The <${SRCDIR}/regress.in')
  @Test func testNormal() throws {
    let x = getFile("xargsTest", "regress.normal", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["echo", "The"], res )
    #expect(j == x)
  }
  
//  REGRESSION_TEST(`n2147483647', `xargs -n2147483647 <${SRCDIR}/regress.in')
  @Test func testN2147483647() throws {
    let x = getFile("xargsTest", "regress.n2147483647", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-n2147483647"], res )
    #expect(j == x)
  }

//  REGRESSION_TEST(`I', `xargs -I% echo The % % % %% % % <${SRCDIR}/regress.in')
  @Test func testI() throws {
    let x = getFile("xargsTest", "regress.I", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-I", "%", "echo", "The", "%", "%", "%", "%%", "%", "%"], res )
    #expect( j == x )
  }

  
//  REGRESSION_TEST(`J', `xargs -J% echo The % again. <${SRCDIR}/regress.in')
  @Test func testJ() throws {
    let x = getFile("xargsTest", "regress.J", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-J", "%", "echo", "The", "%", "again."], res)
    #expect( j == x )
  }

//  REGRESSION_TEST(`L', `xargs -L3 echo <${SRCDIR}/regress.in')
  @Test func testL() throws {
    let x = getFile("xargsTest", "regress.L", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-L3", "echo"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`P1', `xargs -P1 echo <${SRCDIR}/regress.in')
  @Test func testP1() throws {
    let x = getFile("xargsTest", "regress.P1", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-P1", "echo"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`R', `xargs -I% -R1 echo The % % % %% % % <${SRCDIR}/regress.in')
  @Test func testR() throws {
    let x = getFile("xargsTest", "regress.R", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-I", "%", "-R1", "echo", "The", "%", "%", "%", "%%", "%", "%"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`R-1', `xargs -I% -R-1 echo The % % % %% % % <${SRCDIR}/regress.in')
  @Test func testR_1() throws {
    let x = getFile("xargsTest", "regress.R-1", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-I", "%", "-R-1", "echo", "The", "%", "%", "%", "%%", "%", "%"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`n1', `xargs -n1 echo <${SRCDIR}/regress.in')
  @Test func testN1() throws {
    let x = getFile("xargsTest", "regress.n1", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-n1", "echo"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`n2', `xargs -n2 echo <${SRCDIR}/regress.in')
  @Test func testN2() throws {
    let x = getFile("xargsTest", "regress.n2", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-n2", "echo"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`n2P0',`xargs -n2 -P0 echo <${SRCDIR}/regress.in | sort')
  @Test func testN2P0() throws {
    let x = getFile("xargsTest", "regress.n2P0", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-n2", "-P0", "echo"], res )
    let k = (j?.dropLast().components(separatedBy: "\n").sorted().joined(separator: "\n"))!+"\n"
    #expect( k == x )
  }

//  REGRESSION_TEST(`n3', `xargs -n3 echo <${SRCDIR}/regress.in')
  @Test func testN3() throws {
    let x = getFile("xargsTest", "regress.n3", withExtension: "out")
    let res = getFile("xargsTest", "regress", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-n3", "echo"] , res)
    #expect( j == x )
  }

//  REGRESSION_TEST(`0', `xargs -0 -n1 echo <${SRCDIR}/regress.0.in')
  @Test func test0() throws {
    let x = getFile("xargsTest", "regress.0", withExtension: "out")
    let res = getFile("xargsTest", "regress.0", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-0", "-n1", "echo"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`0I', `xargs -0 -I% echo The % %% % <${SRCDIR}/regress.0.in')
  @Test func test0I() throws {
    let x = getFile("xargsTest", "regress.0I", withExtension: "out")
    let res = getFile("xargsTest", "regress.0", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-0", "-I%", "echo", "The", "%", "%%", "%"], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`0J', `xargs -0 -J% echo The % again. <${SRCDIR}/regress.0.in')
  @Test func test0J() throws {
    let x = getFile("xargsTest", "regress.0J", withExtension: "out")
    let res = getFile("xargsTest", "regress.0", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-0", "-J%", "echo", "The", "%", "again."], res )
    #expect( j == x )
  }

//  REGRESSION_TEST(`0L', `xargs -0 -L2 echo <${SRCDIR}/regress.0.in')
  @Test func test0L() throws {
    let x = getFile("xargsTest", "regress.0L", withExtension: "out")
    let res = getFile("xargsTest", "regress.0", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-0", "-L2", "echo"], res )
    #expect( j == x )
  }

  // FIXME: when I forgot the "-" on "-P1" -- I didn't get the error I would have expected
  
//  REGRESSION_TEST(`0P1', `xargs -0 -P1 echo <${SRCDIR}/regress.0.in')
  @Test func test0P1() throws {
    let x = getFile("xargsTest", "regress.0P1", withExtension: "out")
    let res = getFile("xargsTest", "regress.0", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", [ "-0", "-P1", "echo"], res )
    #expect( j == x )
  }

  
//  REGRESSION_TEST(`quotes', `xargs -n1 echo <${SRCDIR}/regress.quotes.in')
  @Test func testQuotes() throws {
    let x = getFile("xargsTest", "regress.quotes", withExtension: "out")
    let res = getFile("xargsTest", "regress.quotes", withExtension: "in")!
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "xargs", ["-n1", "echo"], res )
    #expect( j == x )
  }
}
