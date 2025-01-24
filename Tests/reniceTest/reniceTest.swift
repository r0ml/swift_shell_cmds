
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024
// from a file containing the following notice:

/*
  Copyright (c) 2022-2023 Klara, Inc.

  SPDX-License-Identifier: BSD-2-Clause
*/

import ShellTesting

@Suite("renice", .serialized) struct reniceTest : ShellTest {
  let cmd = "renice"
  let suiteBundle = "shell_cmds_reniceTest"

  @Test("Set a process's nice number to an absolute value") func abs_pid() async throws {
    let pid = run_test_process()
    let prio = Int(getpriority(PRIO_PROCESS, UInt32(pid)))
    let incr = 3
    
    try await run(args: String(prio+incr), String(pid))
    
    let nprio = Int(getpriority(PRIO_PROCESS, UInt32(pid)))
    #expect(nprio == prio+incr)
    
    kill_process(pid)
  }
  
  
  @Test("Change a process's nice number by a relative value") func rel_pid() async throws {
    let pid = run_test_process()
    let prio = Int(getpriority(PRIO_PROCESS, UInt32(pid)))
    let incr = 3
    
    try await run(args: "-n", String(incr), String(pid))
    try await run(args: "-p", "-n", String(incr), String(pid))
    try await run(args: "-n", String(incr), "-p", String(pid))
    
    let nprio = Int(getpriority(PRIO_PROCESS, UInt32(pid)))
    #expect(nprio == prio+incr+incr+incr)

    kill_process(pid)
    
  }

  @Test("Set a process group's nice number to an absolute value") func abs_pgid() async throws {
    let pid = run_test_process()
    let pgrp = UInt32(getpgid(pid))
    let prio = Int(getpriority(PRIO_PGRP, pgrp))
    let incr = 3
    
    try await run(args: "-g", String(prio+incr), String(pgrp))
    
    let nprio = Int(getpriority(PRIO_PGRP, pgrp))
    #expect(nprio == prio+incr)
    
    kill_process(pid)
  }

  @Test("Change a process group's nice number by a relative value") func rel_pgid() async throws {
    let pid = run_test_process()
    let pgrp = UInt32(getpgid(pid))
    let prio = Int(getpriority(PRIO_PGRP, pgrp))
    let incr = 3
    
    try await run(args: "-g", "-n", String(incr), String(pgrp))
    try await run(args: "-n", String(incr), "-g", String(pgrp))
    
    let nprio = Int(getpriority(PRIO_PGRP, pgrp))
    #expect(nprio == prio+incr+incr)
    
    kill_process(pid)
  }
  
  @Test("Set a user's processes nice numbers to an absolute value", .disabled("must have a test user account and run test as root")) func abs_user() async throws {
    let prio = Int(getpriority(PRIO_PROCESS, 0))
    let incr = 3
    let test_user = "test_user"
    
    let pid = run_test_process() // launch a process and get it's pid
    
    try await run(args: "-u", "-n", String(prio+incr), test_user)
    
    let nprio = Int(getpriority(PRIO_PROCESS, UInt32(pid)))
    #expect(nprio == prio+incr)
  }
  
  @Test("Change a user's processes nice numbers by a relative value", .disabled("must have a test user account and run test as root")) func rel_user() throws {
    
  }
  
  @Test("Test various delimiter positions") func delim() async throws {
    
    let pid = run_test_process()
    var incr = 0

    let nice = Int(getpriority(PRIO_PROCESS, UInt32(pid)))

    incr += 1
    try await run(args: "--", String(nice+incr), String(pid))
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(args: String(nice+incr), "--", String(pid))
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(args: String(nice+incr), String(pid), "--")
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(args: "-p", "--", String(nice+incr), String(pid))
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(args: "-p", String(nice+incr), "--", String(pid))
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(args: "-p", String(nice+incr), String(pid), "--")
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(args: String(nice+incr), "-p", "--", String(pid))
    #expect( niceValue(pid) == nice+incr)

    incr += 1
    try await run(withStdin: "--", args: String(nice+incr), "-p", String(pid))
    #expect( niceValue(pid) == nice+incr)

    kill_process(pid)
    
  }
  
  @Test("Do not segfault if -n is given without an argument") func incr_noarg() async throws {
    try await run(status: 1, error: /.+/, args: "-n")
  }

  
  func run_test_process() -> Int32 {
    let process = Process()
    let execu = "/bin/sleep"
    
  //  print("launchPath \(execu)")
    
    process.launchPath = execu
    process.arguments = ["60"]
    process.launch()

    // run a test process (sleep 60 will do) to have a process we can check the nice value of
    return process.processIdentifier
  }
  
  func niceValue(_ pid: Int32) -> Int {
    return Int(getpriority(PRIO_PROCESS, UInt32(pid)))
  }
  
  func kill_process(_ pid : Int32) {
    kill(pid, SIGKILL)
  }
  
}
