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

@Suite("time") struct timeTest : ShellTest {
  let cmd = "time"
  let suiteBundle = "shell_cmds_timeTest"

  @Test("check real time") func timeSleepTest() async throws {
    //    let po = try await ShellProcess(cmd, "sleep", "1").run()
    try await run(args: "sleep", "1") {po in
      #expect(po.code == 0)
      let r = po.string
      let rr = String(r.drop { $0.isWhitespace }.reversed().drop { $0.isWhitespace }.reversed())

      let k = rr.split( separator: " ", omittingEmptySubsequences: true)

      if let kk = k.first,
         let kkk = Double(kk) {
        #expect(kkk > 0)
      } else {
        Issue.record("mis-timed sleep")
      }
    }
  }

  // FIXME: can't figure out how to make the time command get values for those last three items 
  @Test("check instructions retired", .disabled("the instructions retired/cycles elapsed/peak memory footprint members of rusage are always zero")) func instructionsRetired() async throws {
    try await run(output: /instructions retired/, args: "-l", "sleep", "1", env: [:])
  }

  @Test("check child SIGUSR1", .disabled("not sure how the signal handling is working -- but I don't get an error return even though the sleep is interrupted")) func check_child_sigusr1() async throws {

//    let po = try await ShellProcess(cmd,
//    "time", ["sh", "-c", "kill -USR1 $$ && sleep 5 && true"])
    try await run(args: "sh", "-c", "sleep 5 && true") { po in
      print(po.code)
      print(po.string)
      print(po.error)
      #expect(po.code != 0, "should allow child to receive SIGUSR1")
    }
  }
  
  @Test("check non-existent binary") func check_binary() async throws {
    try await run(status: 127, args: "./this-wont-exist")
  }
  
  @Test("check that the -o flag pushes all output to the file") func check_l_stats() async throws {
    try await run(status: 0, error: "", args: "-o", "time_stats", "-l", "true")
  }
  
}
