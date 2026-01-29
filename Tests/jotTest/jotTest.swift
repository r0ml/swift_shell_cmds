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

@Suite("jot Tests", .serialized) final class jotTest : ShellTest {
  let cmd = "jot"
  let suiteBundle = "shell_cmds_jotTest"
  
  func doTest(_ o : String, _ a : [String]) async throws {
    let po = try await ShellProcess(cmd, a).run()
    let ox = try fileContents("regress.\(o).out")
    if ox.contains("\0") || po.string.contains("\0") {
      let cannotShowZero = po.string == ox
      #expect(cannotShowZero)
    } else {
      #expect(po.string == ox)
    }
  }
  
  func doTest(_ o : String, _ a : String) async throws {
    try await doTest(o, Array(a.components(separatedBy: " ").dropFirst() ) )
  }
  
  func doTestError(_ o : String, _ a : String) async throws {
    try await run(status: 1, error: o, args: Array(a.components(separatedBy: " ").dropFirst() ) )
    //    let ox = getFile("regress.\(o)", withExtension: "out")
    // #expect(e == o)
  }
  
  func doTestUniq(_ o : String, _ a : String) async throws {
    let po = try await ShellProcess(cmd, Array(a.components(separatedBy: " ").dropFirst() )).run()
    let ox = try fileContents("regress.\(o).out")

    let jj = (Set(po.string.components(separatedBy: "\n").dropLast()).sorted() + [""]).joined(separator: "\n")

    #expect(jj == ox)
  }
  
  @Test func test01() async throws { try await doTest("x", ["-w", "%X", "-s", ",", "100", "1", "200"]) }
  @Test func test02() async throws { try await doTest("hhhh", "jot 50 20 120 2") }
  @Test func test03() async throws { try await doTest("hhhd", "jot 50 20 120 -") }
  @Test func test04() async throws { try await doTest("hhdh", "jot 50 20 - 2") }
  @Test func test05() async throws { try await doTest("hhdd", "jot 50 20 - -") }
  @Test func test06() async throws { try await doTest("hdhh", "jot 50 - 120 2") }
  @Test func test07() async throws { try await doTest("hdhd", "jot 50 - 120 -") }
  @Test func test08() async throws { try await doTest("hddh", "jot 50 - - 2") }
  @Test func test09() async throws { try await doTest("hddd", "jot 50 - - -") }
  @Test func test10() async throws { try await doTest("dhhh", "jot - 20 120 2") }
  
  @Test func test11() async throws { try await doTest("dhhd", "jot - 20 120 -") }
  @Test func test12() async throws { try await doTest("dhdh", "jot - 20 - 2") }
  @Test func test13() async throws { try await doTest("dhdd", "jot - 20 - -") }
  @Test func test14() async throws { try await doTest("ddhh", "jot - - 120 2") }
  @Test func test15() async throws { try await doTest("ddhd", "jot - - 120 -") }
  @Test func test16() async throws { try await doTest("dddh", "jot - - - 2") }
  @Test func test17() async throws { try await doTest("dddd", "jot - - - -") }
  @Test func test18() async throws { try await doTest("hhhh2", "jot 30 20 160 2") }
  @Test func test19() async throws { try await doTest("hhhd2", "jot 30 20 160 -") }
  @Test func test20() async throws { try await doTest("hhdh2", "jot 30 20 - 2") }
  
  @Test func test21() async throws { try await doTest("hhdd2", "jot 30 20 - -") }
  @Test func test22() async throws { try await doTest("hdhh2", "jot 30 - 160 2") }
  @Test func test23() async throws { try await doTest("hdhd2", "jot 30 - 160 -") }
  @Test func test24() async throws { try await doTest("hddh2", "jot 30 - - 2") }
  @Test func test25() async throws { try await doTest("hddd2", "jot 30 - - -") }
  @Test func test26() async throws { try await doTest("dhhh2", "jot - 20 160 2") }
  @Test func test27() async throws { try await doTest("dhhd2", "jot - 20 160 -") }
  @Test func test28() async throws { try await doTest("ddhh2", "jot - - 160 2") }
  @Test func test29() async throws { try await doTestUniq("rand1", "jot -r 10000 0 9") }
  @Test func test30() async throws { try await doTestUniq("rand2", "jot -r 10000 9 0") }
  
  @Test func test31() async throws { try await doTest("n21", "jot 21 -1 1.00") }
  @Test func test32() async throws { try await doTest("ascii", "jot -c 128 0") }
  @Test func test33() async throws { try await doTest("xaa", "jot -w xa%c 26 a") }
  @Test func test34() async throws { try await doTest("yes", "jot -b yes 10") }
  @Test func test35() async throws { try await doTest("ed", "jot -w %ds/old/new/ 30 2 - 5") }
  @Test func test36() async throws { try await doTest("stutter", "jot - 9 0 -.5") }
  @Test func test37() async throws { try await doTest("stutter2", "jot -w %d - 9.5 0 -.5") }
  @Test func test38() async throws { try await doTest("block", "jot -b x 512") }
  @Test func test39() async throws { try await doTest("tabs", "jot -s, - 10 132 4") }
  @Test func test40() async throws { try await doTest("grep", "jot -s  -b . 80") }
  
  @Test func test41() async throws { try await doTest("wf", "jot -w a%.1fb 10") }
  @Test func test42() async throws { try await doTest("we", "jot -w a%eb 10") }
  @Test func test43() async throws { try await doTest("wwe", "jot -w a%-15eb 10") }
  @Test func test44() async throws { try await doTest("wg", "jot -w a%20gb 10") }
  @Test func test45() async throws { try await doTest("wc", "jot -w a%cb 10 33 43") }
  @Test func test46() async throws { try await doTest("wgd", "jot -w a%gb 10 .2") }
  @Test func test47() async throws { try await doTest("wu", "jot -w a%ub 10") }
  @Test func test48() async throws { try await doTest("wo", "jot -w a%ob 10") }
  @Test func test49() async throws { try await doTest("wx", "jot -w a%xb 10") }
  @Test func test50() async throws { try await doTest("wX1", "jot -w a%Xb 10") }
  
  @Test func test51() async throws { try await doTest("wXl", "jot -w a%Xb 10 2147483648") }
  @Test func test52() async throws { try await doTestError("jot: range error in conversion\n", "jot -w a%db 10 2147483648") }
  @Test func test53() async throws { try await doTestError("jot: range error in conversion\n", "jot -w a%xb 10 -5") }
  @Test func test54() async throws { try await doTest("wdn", "jot -w a%db 10 -5") }
  @Test func test55() async throws { try await doTest("wp1", "jot -w %%%d%%%% 10") }
  @Test func test56() async throws { try await doTest("wp2", "jot -w %d%%d%% 10") }
  @Test func test57() async throws { try await doTest("wp3", "jot -w a%%A%%%d%%B%%b 10") }
  @Test func test58() async throws { try await doTest("wp4", "jot -w %%d%d%%d%% 10") }
  @Test func test59() async throws { try await doTest("wp5", "jot -w ftp://www.example.com/pub/uploaded%%20files/disk%03d.iso 10") }
  @Test func test60() async throws { try await doTest("wp6", "jot -w %d% 10") }
}
