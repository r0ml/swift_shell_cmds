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

@Suite("jot Tests") final class jotTest {
  
  func doTest(_ o : String, _ a : [String]) throws {
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "jot", a)
    let ox = getFile("jotTest", "regress.\(o)", withExtension: "out") ?? "(*** failed to read file ***)"
    if ox.contains("\0") || (j != nil && j!.contains("\0")) {
      let cannotShowZero = j == ox
      #expect(cannotShowZero)
    } else {
      #expect(j == ox)
    }
  }
  
  func doTest(_ o : String, _ a : String) throws {
    try doTest(o, Array(a.components(separatedBy: " ").dropFirst() ) )
  }
  
  func doTestError(_ o : String, _ a : String) throws {
    let (_, _, e) = try captureStdoutLaunch(Clem.self, "jot", Array(a.components(separatedBy: " ").dropFirst() ) )
    //    let ox = getFile("regress.\(o)", withExtension: "out")
    #expect(e == o)
  }
  
  func doTestUniq(_ o : String, _ a : String) throws {
    let (_, j, _) = try captureStdoutLaunch(Clem.self, "jot", Array(a.components(separatedBy: " ").dropFirst() ))
    let ox = getFile("jotTest", "regress.\(o)", withExtension: "out")
    
    let jj = (Set(j!.components(separatedBy: "\n").dropLast()).sorted() + [""]).joined(separator: "\n")
    
    #expect(jj == ox)
  }
  
  @Test func test01() throws { try doTest("x", ["-w", "%X", "-s", ",", "100", "1", "200"]) }
  @Test func test02() throws { try doTest("hhhh", "jot 50 20 120 2") }
  @Test func test03() throws { try doTest("hhhd", "jot 50 20 120 -") }
  @Test func test04() throws { try doTest("hhdh", "jot 50 20 - 2") }
  @Test func test05() throws { try doTest("hhdd", "jot 50 20 - -") }
  @Test func test06() throws { try doTest("hdhh", "jot 50 - 120 2") }
  @Test func test07() throws { try doTest("hdhd", "jot 50 - 120 -") }
  @Test func test08() throws { try doTest("hddh", "jot 50 - - 2") }
  @Test func test09() throws { try doTest("hddd", "jot 50 - - -") }
  @Test func test10() throws { try doTest("dhhh", "jot - 20 120 2") }
  
  @Test func test11() throws { try doTest("dhhd", "jot - 20 120 -") }
  @Test func test12() throws { try doTest("dhdh", "jot - 20 - 2") }
  @Test func test13() throws { try doTest("dhdd", "jot - 20 - -") }
  @Test func test14() throws { try doTest("ddhh", "jot - - 120 2") }
  @Test func test15() throws { try doTest("ddhd", "jot - - 120 -") }
  @Test func test16() throws { try doTest("dddh", "jot - - - 2") }
  @Test func test17() throws { try doTest("dddd", "jot - - - -") }
  @Test func test18() throws { try doTest("hhhh2", "jot 30 20 160 2") }
  @Test func test19() throws { try doTest("hhhd2", "jot 30 20 160 -") }
  @Test func test20() throws { try doTest("hhdh2", "jot 30 20 - 2") }
  
  @Test func test21() throws { try doTest("hhdd2", "jot 30 20 - -") }
  @Test func test22() throws { try doTest("hdhh2", "jot 30 - 160 2") }
  @Test func test23() throws { try doTest("hdhd2", "jot 30 - 160 -") }
  @Test func test24() throws { try doTest("hddh2", "jot 30 - - 2") }
  @Test func test25() throws { try doTest("hddd2", "jot 30 - - -") }
  @Test func test26() throws { try doTest("dhhh2", "jot - 20 160 2") }
  @Test func test27() throws { try doTest("dhhd2", "jot - 20 160 -") }
  @Test func test28() throws { try doTest("ddhh2", "jot - - 160 2") }
  @Test func test29() throws { try doTestUniq("rand1", "jot -r 10000 0 9") }
  @Test func test30() throws { try doTestUniq("rand2", "jot -r 10000 9 0") }
  
  @Test func test31() throws { try doTest("n21", "jot 21 -1 1.00") }
  @Test func test32() throws { try doTest("ascii", "jot -c 128 0") }
  @Test func test33() throws { try doTest("xaa", "jot -w xa%c 26 a") }
  @Test func test34() throws { try doTest("yes", "jot -b yes 10") }
  @Test func test35() throws { try doTest("ed", "jot -w %ds/old/new/ 30 2 - 5") }
  @Test func test36() throws { try doTest("stutter", "jot - 9 0 -.5") }
  @Test func test37() throws { try doTest("stutter2", "jot -w %d - 9.5 0 -.5") }
  @Test func test38() throws { try doTest("block", "jot -b x 512") }
  @Test func test39() throws { try doTest("tabs", "jot -s, - 10 132 4") }
  @Test func test40() throws { try doTest("grep", "jot -s  -b . 80") }
  
  @Test func test41() throws { try doTest("wf", "jot -w a%.1fb 10") }
  @Test func test42() throws { try doTest("we", "jot -w a%eb 10") }
  @Test func test43() throws { try doTest("wwe", "jot -w a%-15eb 10") }
  @Test func test44() throws { try doTest("wg", "jot -w a%20gb 10") }
  @Test func test45() throws { try doTest("wc", "jot -w a%cb 10 33 43") }
  @Test func test46() throws { try doTest("wgd", "jot -w a%gb 10 .2") }
  @Test func test47() throws { try doTest("wu", "jot -w a%ub 10") }
  @Test func test48() throws { try doTest("wo", "jot -w a%ob 10") }
  @Test func test49() throws { try doTest("wx", "jot -w a%xb 10") }
  @Test func test50() throws { try doTest("wX1", "jot -w a%Xb 10") }
  
  @Test func test51() throws { try doTest("wXl", "jot -w a%Xb 10 2147483648") }
  @Test func test52() throws { try doTestError("jot: range error in conversion\n", "jot -w a%db 10 2147483648") }
  @Test func test53() throws { try doTestError("jot: range error in conversion\n", "jot -w a%xb 10 -5") }
  @Test func test54() throws { try doTest("wdn", "jot -w a%db 10 -5") }
  @Test func test55() throws { try doTest("wp1", "jot -w %%%d%%%% 10") }
  @Test func test56() throws { try doTest("wp2", "jot -w %d%%d%% 10") }
  @Test func test57() throws { try doTest("wp3", "jot -w a%%A%%%d%%B%%b 10") }
  @Test func test58() throws { try doTest("wp4", "jot -w %%d%d%%d%% 10") }
  @Test func test59() throws { try doTest("wp5", "jot -w ftp://www.example.com/pub/uploaded%%20files/disk%03d.iso 10") }
  @Test func test60() throws { try doTest("wp6", "jot -w %d% 10") }
}
