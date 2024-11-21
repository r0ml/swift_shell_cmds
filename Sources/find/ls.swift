
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
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

extension find {
  func printlong(name: String, accpath: String, sb: stat) {
    //    var modep = [CChar](repeating: 0, count: 15)
    
    print(String(format: "%6ju %8lld ", sb.st_ino, sb.st_blocks), terminator: "")
    
    let modep = withUnsafeTemporaryAllocation(byteCount: 15, alignment: 1) {p in
      let pp = p.assumingMemoryBound(to: CChar.self).baseAddress!
      strmode(Int32(sb.st_mode), pp)
      return String(cString: pp)
    }
    print(String(format: "%s %3ju %-*s %-*s ", modep, sb.st_nlink,
                 MAXLOGNAME - 1,
                 user_from_uid(sb.st_uid, 0), MAXLOGNAME - 1,
                 group_from_gid(sb.st_gid, 0)), terminator: "")
    
    if (sb.st_mode & S_IFMT) == S_IFCHR || (sb.st_mode & S_IFMT) == S_IFBLK {
      print(String(format: "%#8jx ", sb.st_rdev), terminator: "")
    } else {
      print(String(format: "%8lld ", sb.st_size), terminator: "")
    }
    printtime(sb.st_mtime)
    print(name, terminator: "")
    if (sb.st_mode & S_IFMT) == S_IFLNK {
      printlink(accpath)
    }
    print("")
  }
  
  func printtime(_ ftime: time_t) {
    var longstring = [CChar](repeating: 0, count: 80)
    var lnow: time_t = 0
    var format: String
    var d_first = -1
    
    if d_first < 0 {
      d_first = 1
    }
    if lnow == 0 {
      lnow = time(nil)
    }
    
    let SIXMONTHS = ((365 / 2) * 86400)
    if ftime + SIXMONTHS > lnow && ftime < lnow + SIXMONTHS {
      format = d_first != 0 ? "%e %b %R " : "%b %e %R "
    } else {
      format = d_first != 0 ? "%e %b  %Y " : "%b %e  %Y "
    }
    var fftime = ftime
    if let tm = localtime(&fftime) {
      strftime(&longstring, longstring.count, format, tm)
    } else {
      strlcpy(&longstring, "bad date val ", longstring.count)
    }
    fputs(String(cString: longstring), stdout)
  }
  
  func printlink(_ name: String) {
    //    var path = [CChar](repeating: 0, count: MAXPATHLEN)
    
    withUnsafeTemporaryAllocation(byteCount: Int(MAXPATHLEN), alignment: 1) { p in
      let pp = p.assumingMemoryBound(to: CChar.self).baseAddress!
      let lnklen = readlink(name, pp, Int(MAXPATHLEN) - 1)
      if lnklen == -1 {
        print(name, terminator: "")
        return
      }
      p[Int(lnklen)] = 0
      print(String(format: " -> %s", String(cString: pp)), terminator: "")
    }
  }
}
