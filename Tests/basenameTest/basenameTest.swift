
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 
// from a file containing the following notice:

/*
  Copyright (c) 2008 The NetBSD Foundation, Inc.
  All rights reserved.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
*/

import ShellTesting

@Suite("basename tests") final class Tests : ShellTest {
  let cmd = "basename"
  let suiteBundle = "shell_cmds_basenameTest"
  
  @Test(.serialized, arguments: [("/usr/bin", "bin"), ("/usr", "usr"), ("/", "/") , ("///", "/"), ("/usr//", "usr"), ("//usr//bin", "bin"), ("usr", "usr"), ("usr/bin", "bin")])
  func testBasic(_ i : String, _ o : String) async throws {
    try await run(output: o+"\n", args: i)

  }

  @Test(arguments: [("usr/bin", "n", "bi"), ("usr/bin", "bin", "bin"), ("/", "/", "/"), ("/usr/bin/gcc", "cc", "g")])
  func testSuffix(_ inp : String, _ suff : String, _ o : String) async throws {
    try await run(output: o+"\n", args: inp, suff)
  }
}
