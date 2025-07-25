
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from files containing the following notices:

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

/*
 * Copyright (c) 1997, 2004 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */


import CMigration

@main final class dirnameTool :ShellCommand {
  struct CommandOptions {
    var args : [String] = []
  }

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var opts = CommandOptions()
    let go = BSDGetopt("")
    while let (_, _) = try go.getopt() {
      throw CmdErr(1)
    }

    opts.args = go.remaining

    if opts.args.count < 1 {
      throw CmdErr(1)
    }
    return opts
  }

  func runCommand(_ opts : CommandOptions) throws(CmdErr) {
    for v in opts.args {
        if let p = try? dirname(v) {
          print( p )
        }
    }
  }

  var usage = "usage: dirname string [...]"

  func dirname(_ path : String) throws(CmdErr) -> String {
    // Empty string gets treated as "."
    if path.isEmpty {
      return "."
    }

    var ppath = Substring(path)

    // Strip any trailing slashes
    while ppath.last == "/" {
      ppath = ppath.dropLast()
    }

    // Find the start of the dir
    while !ppath.isEmpty && ppath.last != "/" {
      ppath = ppath.dropLast()
    }

    // Either the dir is "/" or there are no slashes
    if ppath.count <= 1 {
      return path.first == "/" ? "/" : "."
    } else {
      // Move forward past the separating slashes
      repeat {
        ppath = ppath.dropLast()
      } while !ppath.isEmpty && ppath.last == "/"
    }

    if ppath.count >= MAXPATHLEN {
      throw CmdErr(1, POSIXErrno(ENAMETOOLONG).localizedDescription)
    }

    return String(ppath)
  }
}


