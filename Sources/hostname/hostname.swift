
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1988, 1993
 *  The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

import Foundation
import shared

@main final class hostname : ShellCommand {
  var args = Array<String>.SubSequence()
  var sflag = 0
  var dflag = 0

  func parseOptions() throws(CmdErr) {
    
    let go = BSDGetopt("fsd")
    while let(ch, _) = try go.getopt() {
      switch ch {
      case "f":
        break
      case "s":
        sflag = 1
      case "d":
        dflag = 1
      case "?":
        fallthrough
      default:
        throw CmdErr(1)
      }
    }
    
    self.args = ArraySlice( go.remaining)
    
    
    if args.count > 1 || (sflag != 0 && dflag != 0) {
      throw CmdErr(1)
    }
  }
  
  func runCommand() throws(CmdErr) {
    if let arg = args.first {
      if sethostname(arg, Int32(arg.count)) != 0 {
        err(1, "sethostname")
      }
    } else {
      var hostnamed = Data(count: Int(MAXHOSTNAMELEN))
      var hostname = hostnamed.withUnsafeMutableBytes { p in
        let px = p.baseAddress!.assumingMemoryBound(to: CChar.self)
        if gethostname(px, Int(MAXHOSTNAMELEN)) != 0 {
          err(1, "gethostname")
          
        }
        
        return String(cString: px)
      }
      if sflag != 0 {
        hostname = String(hostname.prefix { $0 != "." })
      } else if dflag != 0 {
        if let dot = hostname.firstIndex(of: ".") {
          hostname = String(hostname.suffix(from: dot).dropFirst())
        }
      }
      print(hostname)
    }
  }
  
  var usage = "usage: hostname [-f] [-s | -d] [name-of-host]"

}
