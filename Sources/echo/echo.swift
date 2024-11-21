
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * Copyright (c) 1989, 1993
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
 * 4. Neither the name of the University nor the names of its contributors
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

@main struct Echo {
  static func main() {
    
    var args = CommandLine.arguments
    args.removeFirst() // this is the executable name
    var nflag = false
    let posix = getenv("POSIXLY_CORRECT") != nil || getenv("POSIX_PEDANTIC") != nil
    
    if !posix && args[0] == "-n" {
      nflag = true
      args.removeFirst()
    }
    
    var firstTime = true
    for arg in args {
      if !firstTime {
        putchar(32)
      } else {
        firstTime = false
      }
      
      var a = arg
      while let x = a.firstIndex(of: "\\") {
        print(a[a.startIndex..<x], terminator: "")
        a = String(a[ a.index(x, offsetBy: 1)...])
        printEscapeChar(cur: &a, posix: posix)
      }
      print(a, terminator: "")
    }
    
    if !nflag {
      putchar(10)
    }
    
    
    /*
     for _ in 0..<argLen {
     cur = printOneChar(cur: cur!, posix: posix, bytesLenOut: &bytesLen)
     }
     
     if lastArg && nflag == 0 {
     putchar(10)
     } else if !lastArg && !ignoreArg {
     putchar(32)
     }
     
     fflush(stdout)
     */
    
    fflush(stdout)
    exit(0)
  }
  
  static func printEscapeChar(cur: inout String, posix: Bool) {
    if cur.isEmpty {
      putchar(92)
      return
    }
    
    let z =  cur.removeFirst()
    if z == "c" {
      fflush(stdout)
      exit(0)
    }
    
    if !posix {
      print(z, terminator: "")
    }

    switch z {
          case "a":
              putchar(7)
          case "b":
              putchar(8)
          case "f":
              putchar(12)
          case "n":
              putchar(10)
          case "r":
              putchar(13)
          case "t":
              putchar(9)
          case "v":
              putchar(11)
          case "\\":
              putchar(92)
          case "0":
              var j = 0, num = 0
      while true {
        if cur.isEmpty {
          break
        }
        let n = cur.first!.asciiValue
        if let n,
           n >= 48 && n <= 55 && j < 3 {
          num *= 8
          num += Int(n) - 48
          j += 1
          cur.removeFirst()
        } else {
          break
        }
      }
              putchar(Int32(num))
          default:
      print( z, terminator: "" )
          }
      }

  
}
