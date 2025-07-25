
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1985, 1987, 1988, 1993
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

import locale_h
import stdlib_h
import stdio_h
import time_h

import Darwin

@main final class Date : ShellCommand {

  // from vary.swift
  struct trans {
    var val: Int
    var str: String
  }

  var trans_mon: [trans] = [
    trans(val: 1, str: "january"), trans(val: 2, str: "february"), trans(val: 3, str: "march"), trans(val: 4, str: "april"),
    trans(val: 5, str: "may"), trans(val: 6, str: "june"), trans(val: 7, str: "july"), trans(val: 8, str: "august"),
    trans(val: 9, str: "september"), trans(val: 10, str: "october"), trans(val: 11, str: "november"), trans(val: 12, str: "december"),
    trans(val: -1, str: "")
  ]

  var trans_wday: [trans] = [
    trans(val: 0, str: "sunday"), trans(val: 1, str: "monday"), trans(val: 2, str: "tuesday"), trans(val: 3, str: "wednesday"),
    trans(val: 4, str: "thursday"), trans(val: 5, str: "friday"), trans(val: 6, str: "saturday"),
    trans(val: -1, str: "")
  ]

  var digits: [Character] = Array("0123456789")

  var mdays: [Int] = [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  // ===============================

  var tval: time_t = 0

  struct iso8601_fmt {
    var refname: String
    var format_string: String
  }

  let iso8601_fmts = [
    iso8601_fmt(refname: "date", format_string: "%Y-%m-%d"),
    iso8601_fmt(refname: "hours", format_string: "T%H"),
    iso8601_fmt(refname: "minutes", format_string: ":%M"),
    iso8601_fmt(refname: "seconds", format_string: ":%S")
  ]

  var iso8601_selected: iso8601_fmt?


  let rfc2822_format = "%a, %d %b %Y %T %z"

  let TM_YEAR_BASE : Int32 = 1900
  var unix2003_std = false
  var buf = [CChar](repeating: 0, count: 1024)

  struct CommandOptions {
    var argv : [String] = []
    var rflag: Bool = false
    var Iflag: Bool = false
    var jflag: Bool = false
    var Rflag: Bool = false
    var format: String = ""
    var fmt: String?
    var v: Vary?
    var iso8601_subset : [iso8601_fmt]!
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var opts = CommandOptions()
    var sb: Darwin.stat! = Darwin.stat()

    unix2003_std = true // compat_mode("bin/date", "unix2003")

    opts.v = nil
    opts.fmt = nil

    let go = BSDGetopt("f:I::jnRr:uv:")
    while let (ch, optarg) = try go.getopt() {
      switch ch {
        case "f":
          opts.fmt = optarg
        case "I":
          if opts.Rflag {
            multipleformats()
          }
          opts.Iflag = true
          if optarg.isEmpty {
            opts.iso8601_subset = [iso8601_fmts[0]]
            break
          }
          for i in 0...iso8601_fmts.count {
            if i == iso8601_fmts.count {
              iso8601_usage(optarg)
              break
            }

            if optarg == iso8601_fmts[i].refname {
              opts.iso8601_subset = Array(iso8601_fmts.prefix(through: i))
              break
            }
          }
        case "j":
          opts.jflag = true
        case "n":
          break
        case "R":
          if opts.Iflag {
            multipleformats()
          }
          opts.Rflag = true
        case "r":
          opts.rflag = true
          var tmp: UnsafeMutablePointer<CChar>?
          tval = time_h.time_t(stdlib_h.strtoq(optarg, &tmp, 0))
          if tmp!.pointee != 0 {
            let sr  = optarg.withCString { oo in
              // FIXME: Darwin.stat won't compile because there is ambiguity between
              // the type `stat` and the function `stat`
              // https://github.com/swiftlang/swift/issues/57418
              stat(oo, &sb)
            }
            if sr == 0 {
              // FIXME:  st_mtim  for non-Apple platforms
              tval = sb.st_mtimespec.tv_sec
            } else {
              throw CmdErr(1)
            }
          }
        case "u":
          stdlib_h.setenv("TZ", "UTC0", 1)
        case "v":
          opts.v?.append(optarg)
        default:
          throw CmdErr(1)
      }
    }

    opts.argv = go.remaining


    if !opts.rflag && time_h.time(&tval) == -1 {
      err(1, "time")
    }

    opts.format = "%+"

    if opts.Rflag {
      opts.format = rfc2822_format
    }

    if let firstArg = opts.argv.first, firstArg.hasPrefix("+") {
      if opts.Iflag {
        multipleformats()
      }
      opts.format = String(firstArg.dropFirst())
      opts.argv.removeFirst()
    }

    if let firstArg = opts.argv.first {
      try setthetime(opts.fmt, firstArg, opts.jflag)
      opts.argv.removeFirst()
    } else if opts.fmt != nil {
      throw CmdErr(1)
    }

    if let firstArg = opts.argv.first, firstArg.hasPrefix("+") {
      if opts.Iflag {
        multipleformats()
      }
      opts.format = String(firstArg.dropFirst())
    }
    return opts
  }

  func runCommand(_ opts: CommandOptions) throws(CmdErr) {

    var lt = time_h.localtime(&tval).pointee
    if let v = opts.v {
      if let badv = vary_apply(v, &lt) {
        throw CmdErr(1, "\(badv): Cannot apply date adjustment")
      }
    }

    if opts.Iflag {
      printisodate(&lt, opts.iso8601_subset)
    }

    if opts.format == rfc2822_format {
      locale_h.setlocale(locale_h.LC_TIME, "C")
    }

    strftime(&buf, buf.count, opts.format, &lt)
    let k = String(platformString: buf)
    printdate(k)
  }


  func printdate(_ buf: String) {
    print(buf)
    if fflush(stdout) != 0 {
      err(1, "stdout")
    }
    exit(EXIT_SUCCESS)
  }

  func printisodate(_ lt: UnsafeMutablePointer<tm>, _ iso8601_subset: [iso8601_fmt]) {
    var fmtbuf : String = ""
    let bs = 32

    //    fmtbuf[0] = 0
    for it in iso8601_subset {
      fmtbuf +=  it.format_string
    }

    var buf = withUnsafeTemporaryAllocation(of: CChar.self, capacity: bs) {
      let n = strftime($0.baseAddress, bs, fmtbuf, lt)
      return String($0[0..<n].map { Character(UnicodeScalar(UInt8($0)))})
    }

    if iso8601_subset.count > 1 {
      let tzx = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 8) {
        let n = strftime($0.baseAddress, $0.count, "%z", lt)
        return String( $0[0..<n].map { Character(UnicodeScalar(UInt8($0)))} )
      }
      let tz = tzx.prefix(3)+":"+tzx.dropFirst(3)

      //        memmove(&tzbuf + 4, &tzbuf + 3, 3)
      //        tzbuf[3] = 58 // ASCII value for ':'
      //  strlcat(&buf, tzbuf, MemoryLayout.size(ofValue: buf))
      buf += tz
    }

    printdate(buf )
  }

  func setthetime(_ fmt: String?, _ p: String, _ jflag: Bool) throws(CmdErr) {
    var utx = Darwin.utmpx()
    var tv = time_h.timeval()
    var century: Int32

    guard let lt = time_h.localtime(&tval) else {
      throw CmdErr(1, "invalid time")
    }

    lt.pointee.tm_isdst = -1

    if let fmt {
      guard let t = time_h.strptime(p, fmt, lt) else {
        stdio_h.fputs("Failed conversion of ``\(p)'' using format ``\(fmt)''\n", stdio_h.stderr)
        throw badformat
      }
      if t.pointee != 0 {
        stdio_h.fputs("Warning: Ignoring \(strlen(t)) extraneous characters in date string \(t)\n", stdio_h.stderr)
      }
    } else {
      var t = p
      var dot : String? = nil
      while !t.isEmpty {
        let tf = t.first!
        if tf.isNumber {
          t.removeFirst()
          continue
        }
        if tf == "." && dot == nil {
          dot = t
          t.removeFirst()
          continue
        }
        throw badformat
      }

      if dot != nil {
        dot!.removeFirst()
        if dot!.count != 2 {
          throw badformat
        }
        lt.pointee.tm_sec = Int32(dot!)!
        if lt.pointee.tm_sec > 61 {
          throw badformat
        }
      } else {
        lt.pointee.tm_sec = 0
      }

      century = 0
      let length = p.count - (dot != nil ? 3 : 0)
      switch length {
        case 12:
          lt.pointee.tm_year = (unix2003_std ? ATOI2_OFFSET(p, length - 4) : ATOI2(p)) * 100 - TM_YEAR_BASE
          century = 1
          fallthrough
        case 10:
          if century != 0 {
            lt.pointee.tm_year += (unix2003_std ? ATOI2_OFFSET(p, length - 2) : ATOI2(p))
          } else {
            lt.pointee.tm_year = (unix2003_std ? ATOI2_OFFSET(p, length - 2) : ATOI2(p))
            if lt.pointee.tm_year < 69 {
              lt.pointee.tm_year += 2000 - TM_YEAR_BASE
            } else {
              lt.pointee.tm_year += 1900 - TM_YEAR_BASE
            }
          }
          fallthrough
        case 8:
          lt.pointee.tm_mon = ATOI2(p)
          if lt.pointee.tm_mon > 12 {
            throw badformat
          }
          lt.pointee.tm_mon -= 1
          fallthrough
        case 6:
          lt.pointee.tm_mday = ATOI2(p)
          if lt.pointee.tm_mday > 31 {
            throw badformat
          }
          fallthrough
        case 4:
          lt.pointee.tm_hour = Int32(p)!
          if lt.pointee.tm_hour > 23 {
            throw badformat
          }
          fallthrough
        case 2:
          lt.pointee.tm_min = Int32(p)!
          if lt.pointee.tm_min > 59 {
            throw badformat
          }
        default:
          throw badformat
      }
    }

    if mktime(lt) == -1 {
      err(1, "nonexistent time")
    }

    if !jflag {
      utx.ut_type = Int16(OLD_TIME)
      Darwin.memset(&utx.ut_id, 0, MemoryLayout.size(ofValue: utx.ut_id))
      Darwin.gettimeofday(&utx.ut_tv, nil)
      Darwin.pututxline(&utx)
      tv.tv_sec = tval
      tv.tv_usec = 0
      if settimeofday(&tv, nil) != 0 {
        err(1, "settimeofday (timeval)")
      }
      utx.ut_type = Int16(Darwin.NEW_TIME)
      Darwin.gettimeofday(&utx.ut_tv, nil)
      Darwin.pututxline(&utx)

      var ll = "???"
      if let p = Darwin.getlogin() { ll = String(cString: p) }


      // FIXME: is this right?
      ll.withCString {  withVaList([$0]) { Darwin.vsyslog(LOG_NOTICE, "date set by %s", $0 )  } }
    }
  }

  func ATOI2(_ p : String) -> Int32 {
    return Int32(p)!
  }

  func ATOI2_OFFSET(_ p : String, _ n : Int) -> Int32 {
    return Int32(p.dropFirst(n))!
  }

  var badformat = CmdErr(1, "illegal time format")

  func iso8601_usage(_ badarg: String) {
    err(1, "invalid argument '\(badarg)' for -I")
  }

  func multipleformats() {
    err(1, "multiple output formats specified")
  }

  var usage : String { get {
    return """
usage: date [-jnRu] [-I[date|hours|minutes|seconds]] [-f input_fmt]
            [-r filename|seconds] [-v[+|-]val[y|m|w|d|H|M|S]]
""" + (unix2003_std ?
       "            [[[[mm]dd]HH]MM[[cc]yy][.SS] | new_date] [+output_fmt]" :
        "            [[[[[[cc]yy]mm]dd]HH]MM[.SS] | new_date] [+output_fmt]"
)

  }
  }
}
