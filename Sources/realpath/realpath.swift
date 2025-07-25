
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1991, 1993, 1994
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

import CMigration

import limits_h
import stdlib_h
import stdio_h

@main class realpath {
  var qflag = 0
  var rval = 0
  var path: String?
  var p: UnsafeMutablePointer<Int8>?
  var buf = [Int8](repeating: 0, count: Int(limits_h.PATH_MAX))

  required init() {}
  
  static func main() {
    let z = Self().main()
    stdlib_h.exit(z)
  }
  
  func main() -> Int32 {
    // FIXME: CommandLine arguments is read-only
    let zz = CommandLine.arguments.dropFirst() // equivalent to argc -= optind; argv += optind;
    
    for argument in zz {
      if argument == "-q" {
        qflag = 1
      } else {
        path = argument
      }
    }
    
    path = path ?? "."
    
    var aa = CommandLine.arguments
    repeat {
      withUnsafeMutablePointer(to: &buf) { b in
        p = stdlib_h.realpath(path, b)
      }
      
      if p == nil {
        if qflag == 0 {
          print("Warning: \(path ?? "")")
        }
        rval = 1
      } else {
        print(String(cString: p!))
      }
      path = aa.removeFirst()
    } while path != nil
    
    return Int32(rval)
  }
  
    func usage() {
      stdio_h.fputs("usage: realpath [-q] [path ...]\n", stdio_h.stderr)
      stdlib_h.exit(1)
    }
    }
