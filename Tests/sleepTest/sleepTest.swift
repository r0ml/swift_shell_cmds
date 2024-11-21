
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024
// from a file containing the following notice:

/*
  $NetBSD: t_sleep.sh,v 1.1 2012/03/30 09:27:10 jruoho Exp $
 
  Copyright (c) 2012 The NetBSD Foundation, Inc.
  All rights reserved.
 
  This code is derived from software contributed to The NetBSD Foundation
  by Jukka Ruohonen.
 
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

import Testing
import testSupport

@Suite("sleep") struct sleepTest {
  
  @Test("Test that sleep(1) handles fractions of a second") func fraction() throws {
    for i in [0.1, 0.2, 0.3] {
      let (c, r, j) = try captureStdoutLaunch(Clem.self, "sleep", [String(i)] )
      #expect(c == 0)
      #expect(r!.isEmpty)
      #expect(j!.isEmpty)
    }
  }

  @Test("Test that sleep(1) errors out with non-numeric argument") func nonnumeric() throws {
    for i in ["xyz", "x21", "/3"] {
      let (c, r, j) = try captureStdoutLaunch(Clem.self, "sleep", [i] )
      #expect(c != 0)
      #expect(r!.isEmpty)
      #expect(!j!.isEmpty)
    }
  }
  
  @Test("Test that sleep(1) handles hexadecimal arguments") func hex() throws {
    let (c,r,j) = try captureStdoutLaunch(Clem.self, "sleep", ["0x01"])

    #expect(c == 0)
    #expect(r!.isEmpty)
    #expect(j!.isEmpty)
  }

}
