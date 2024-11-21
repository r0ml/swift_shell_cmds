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
import Foundation

@Suite("time") struct timeTest {

  @Test("check real time") func timeSleepTest() throws {
    let (c, r, j) = try captureStdoutLaunch(Clem.self, "time", ["sleep", "1"])
    #expect(c == 0)
    if let r {
      let rr = r.trimmingCharacters(in: .whitespaces)
      let k = rr.split(separator: /\ +/)
      if let kk = k.first,
         let kkk = Double(kk) {
        #expect(kkk > 0)
      } else {
        Issue.record("mis-timed sleep")
      }
    } else {
      Issue.record("no output")
    }
    }

  // FIXME: can't figure out how to make the time command get values for those last three items 
  @Test("check instructions retired", .disabled("the instructions retired/cycles elapsed/peak memory footprint members of rusage are always zero")) func instructionsRetired() throws {
    let (c, r, j) = try captureStdoutLaunch(Clem.self, "time", ["-l", "sleep", "1"], nil, [:])
    #expect(c == 0)
    #expect(r!.contains("instructions retired"))
  }

  @Test("check child SIGUSR1", .disabled("not sure how the signal handling is working -- but I don't get an error return even though the sleep is interrupted")) func check_child_sigusr1() throws {

    let (c, r, j) = try captureStdoutLaunch(Clem.self,
//    "time", ["sh", "-c", "kill -USR1 $$ && sleep 5 && true"])
    "time", ["sh", "-c", "sleep 5 && true"])
    
    print(c)
    print(r)
    print(j)
    
    #expect(c != 0, "should allow child to receive SIGUSR1")
  }
  
  @Test("check non-existent binary") func check_binary() throws {
    let (c,r,j) = try captureStdoutLaunch(Clem.self, "time", ["./this-wont-exist"])
    #expect(c == 127, "should error when measuring a non-existent command")
  }
  
  @Test("check that the -o flag pushes all output to the file") func check_l_stats() throws {
    let (c,r,j) = try captureStdoutLaunch(Clem.self, "time", ["-o", "time_stats", "-l", "true"])
    #expect(c == 0)
    #expect(j!.isEmpty, "stderr should have been empty with -o specified")
  }
  
}
