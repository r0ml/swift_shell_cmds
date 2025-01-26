
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1989, 1993
 *  The Regents of the University of California.  All rights reserved.
 * Portions copyright (c) 2007 Apple Inc.  All rights reserved.
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
import CMigration

let FILENAME = "nohup.out"
let EXIT_NOEXEC : Int32 = 126
let EXIT_NOTFOUND : Int32 = 127
let EXIT_MISC : Int32 = 127

@main class nohup {
  static func main() {
    Self().main()
  }
  
  required init() {}
  
  func main() {
    var exit_status: Int32
    
    let argv = CommandLine.arguments
    if argv.count < 2 {
      usage()
    }
    
    if isatty(STDOUT_FILENO) != 0 {
      dofile()
    }
    if isatty(STDERR_FILENO) != 0 && dup2(STDOUT_FILENO, STDERR_FILENO) == -1 {
      // may have just closed stderr
      fatalError("\(argv[0])")
    }
    
    signal(SIGHUP, SIG_IGN)
    
    let argvv = argv.map { strdup($0) }
    execvp(argv[1], argvv)
    exit_status = (errno == ENOENT) ? EXIT_NOTFOUND : EXIT_NOEXEC
    return 
    err( Int(exit_status), argv[1] )
  }
  
  func dofile() {
    var fd: Int32
    var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    var p: String
    
    p = FILENAME
    fd = open(p, O_RDWR | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
    if fd != -1 {
      dupit(fd: fd, p: p)
    }
    if let home = getenv("HOME"), home.pointee != 0 {
      let pathString = String(format: "%s/%s", home, FILENAME)
      fd = open(pathString, O_RDWR | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
      if fd != -1 {
        dupit(fd: fd, p: pathString)
        return
      }
    }
    errx(Int(EXIT_MISC), "can't open a nohup.out file")
  }
  
  func dupit(fd: Int32, p: String) {
    lseek(fd, 0, SEEK_END)
    if dup2(fd, STDOUT_FILENO) == -1 {
      fatalError()
    }
    print("appending output to \(p)")
  }
  
  func usage() {
    print("usage: nohup [--] utility [arguments]")
    exit(EXIT_MISC)
  }
}
