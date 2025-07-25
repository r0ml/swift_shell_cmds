
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1990, 1993
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

import Darwin


let PADDING = "         "
let TYPE_OFFSET = 7


extension hexdump {
  
  func oldsyntax(_ opts : inout CommandOptions) throws(CmdErr) {
#if os(macOS)
    let _n = "%_n"
    let padding = PADDING
#else
    var empty = ""
    var padding = PADDING
#endif
    
    odadd("\"%07.7_Ao\n\"")
    odadd("\"%07.7_ao  \"")
    odmode = true
    
      let go = BSDGetopt("A:aBbcDdeFfHhIij:LlN:Oost:vXx")
      while let (ch, optarg) = try go.getopt() {

//          let chx = getopt(argc, argv, "A:aBbcDdeFfHhIij:LlN:Oost:vXx")
//      if chx == -1 { break }
//      let ch = Character.from(UInt8(chx))
      switch ch {
      case "A":
        let of = optarg.first
        switch of {
        case "d", "o", "x":
          var z = Array(fsArray[0].fuArray[0].fmt)
          z[TYPE_OFFSET] = of!
          fsArray[0].fuArray[0].fmt = String(z)
          
          z = Array(fsArray[1].fuArray[0].fmt)
          z[TYPE_OFFSET] = of!
          fsArray[1].fuArray[0].fmt = String(z)
        case "n":
#if os(macOS)
          fsArray[0].fuArray[0].fmt = _n
#else
          fsArray[0].fuArray[0].fmt = empty
#endif
          fsArray[1].fuArray[0].fmt = padding
        default:
          fatalError("\(optarg): invalid address base")
        }
      case "a":
        odformat("a")
      case "B", "o":
        odformat("o2")
      case "b":
        odformat("o1")
      case "c":
        odformat("c")
      case "d":
        odformat("u2")
      case "D":
        odformat("u4")
      case "e", "F":
        odformat("fD")
      case "f":
        odformat("fF")
      case "H", "X":
        odformat("x4")
      case "h", "x":
        odformat("x2")
      case "I", "L", "l":
        odformat("dL")
      case "i":
        odformat("dI")
      case "j":
        var end : UnsafeMutablePointer<CChar>?
        skip = strtoll(optarg, &end, 0)
        let cfe = Character.from(end!.pointee)
        switch(cfe) {
        case "b":
          skip *= 512
        case "k":
          skip *= 1024
        case "m":
          skip *= 1048576
        case "g":
          skip *= 1073741824
        default:
          break
        }
        if errno != 0 || skip < 0 || strlen(end!) > 1 {
          fatalError("\(optarg): invalid skip amount")
        }
      case "N":
        let arg = optarg
        if let length = Int(arg), length <= 0 {
          fatalError("\(arg): invalid length")
        }
      case "O":
        odformat("o4")
      case "s":
        odformat("d2")
      case "t":
        odformat(optarg)
      case "v":
          opts.vflag = .ALL
      case "?":
        fallthrough
      default:
        throw CmdErr(1)
      }
    }
    
    if fsArray.count == 2 {
      odformat("oS")
    }
    
      opts.args = Array.SubSequence( go.remaining )

  if opts.args.count != 0 {
      odoffset(&opts)
    }
  }
  
  func odoffset( _ opts : inout CommandOptions) {
//    var p: [UInt8]?, q: [UInt8]?, num: [UInt8]?, end: [UInt8]?
    var base: Int
    var num : Substring
    
    /*
     * The offset syntax of od(1) was genuinely bizarre.  First, if
     * it started with a plus it had to be an offset.  Otherwise, if
     * there were at least two arguments, a number or lower-case 'x'
     * followed by a number makes it an offset.  By default it was
     * octal; if it started with 'x' or '0x' it was hex.  If it ended
     * in a '.', it was decimal.  If a 'b' or 'B' was appended, it
     * multiplied the number by 512 or 1024 byte units.  There was
     * no way to assign a block count to a hex offset.
     *
     * We assume it's a file if the offset is bad.
     */
    var p = Substring(opts.args.count == 1 ? opts.args[0] : opts.args[1])
    
    if p.first != "+" && (opts.args.count < 2 || !(p.first!.isNumber )  && (p.first! != "x") || !p.dropFirst().first!.isHexDigit) {
      return
    }
    
    base = 0
    /*
     * skip over leading '+', 'x[0-9a-fA-f]' or '0x', and
     * set base.
     */
    if p.hasPrefix("+") {
      p = p.dropFirst()
    }
    if p.hasPrefix("x") &&
        p.dropFirst().first!.isHexDigit {
      p = p.dropFirst()
      base = 16
    } else if p.hasPrefix("0x") {
      p = p.dropFirst(2)
      base = 16
    }
    
    /* skip over the number */
    if base == 16 {
      num = p.prefix(while: { $0.isHexDigit })
    } else {
      num = p.prefix(while: { $0.isNumber })
    }
    p = p.dropFirst(num.count)

    /* check for no number */
    if num.isEmpty {
      return
    }
    
    /* if terminates with a '.', base is decimal */
    if p.hasPrefix(".") {
      if base != 0 {
        return
      }
      base = 10
    }
    
    if let x = Int64(num, radix: base != 0 ? base : 8) {
      skip = x
    } else {
      /* if end isn't the same as p, we got a non-octal digit */
      skip = 0
      return
    }
    
    if !p.isEmpty {
      if p.hasPrefix("B") {
        skip *= 1024
        p = p.dropFirst()
      } else if p.hasPrefix("b") {
        skip *= 512
        p = p.dropFirst()
        
      } else {
#if __APPLE__
        if p.hasPrefix(".") {
          p = p.dropFirst()
        }
#endif
      }
    }
    
    if !p.isEmpty {
      skip = 0
      return
    }
    
    if base == 16 {
      var z = Array(fsArray[0].fuArray[0].fmt)
      z[TYPE_OFFSET] = "x"
      fsArray[0].fuArray[0].fmt = String(z)
      
      z = Array(fsArray[1].fuArray[0].fmt)
      z[TYPE_OFFSET] = "x"
      fsArray[1].fuArray[0].fmt = String(z)
    } else if base == 10 {
      var z = Array(fsArray[0].fuArray[0].fmt)
      z[TYPE_OFFSET] = "d"
      fsArray[0].fuArray[0].fmt = String(z)
      
      z = Array(fsArray[1].fuArray[0].fmt)
      z[TYPE_OFFSET] = "d"
      fsArray[1].fuArray[0].fmt = String(z)
    }
    
    opts.args = opts.args.prefix(1)
  }
  
  
  
  
  
  func odformat(_ fmt: String) {
    var fchar: Character
    var fmt = fmt
    
    while !fmt.isEmpty {
      fchar = fmt.removeFirst()
      switch fchar {
      case "a":
        odadd("16/1 \"%3_u \" \"\\n\"")
      case "c":
        odadd("16/1 \"%3_c \" \"\\n\"")
      case "o", "u", "d", "x":
        fmt = odformatint(fchar: fchar, fmt: fmt)
      case "f":
        fmt = odformatfp(fchar: fchar, fmt: fmt)
      default:
        fatalError("\(fchar): unrecognised format character")
      }
    }
  }
  
  func odformatfp(fchar: Character, fmt: String) -> String {
    var isize: Int
    var digits: Int
    var fmt = fmt
    var hdfmt: String
    
    isize = MemoryLayout<Double>.size
    switch fmt.first {
    case "F":
      isize = MemoryLayout<Float>.size
      fmt.removeFirst()
    case "D":
      isize = MemoryLayout<Double>.size
      fmt.removeFirst()
    case "L":
      isize = MemoryLayout<CLongDouble>.size
      fmt.removeFirst()
    default:
      if let firstChar = fmt.first, firstChar.isNumber {
        isize = Int(fmt) ?? 0
        if isize == 0 {
          fatalError("\(fmt): invalid size")
        }
        fmt.removeFirst()
      }
    }
    switch isize {
    case MemoryLayout<Float>.size:
      digits = Int(FLT_DIG)
    case MemoryLayout<Double>.size:
      digits = Int(DBL_DIG)
    default:
      if isize == MemoryLayout<CLongDouble>.size {
        digits = Int(LDBL_DIG)
      } else {
        fatalError("unsupported floating point size \(isize)")
      }
    }
    
    hdfmt = cFormat("%lu/%lu \" %%%d.%de \" \"\\n\"", 16 / isize, isize, digits + 8, digits)
    odadd(hdfmt)
    
    return fmt
  }
  
  func odformatint(fchar: Character, fmt: String) -> String {
    var n: UInt64
    var isize: Int
    var digits: Int
    var fmt = fmt
    var hdfmt: String
    
    isize = MemoryLayout<Int>.size
    switch fmt.first {
    case "C":
      isize = MemoryLayout<Int8>.size
      fmt.removeFirst()
    case "I":
      isize = MemoryLayout<Int>.size
      fmt.removeFirst()
    case "L":
      isize = MemoryLayout<Int64>.size
      fmt.removeFirst()
    case "S":
      isize = MemoryLayout<Int16>.size
      fmt.removeFirst()
    default:
      if let firstChar = fmt.first, firstChar.isNumber {
        isize = Int(fmt) ?? 0
        if isize == 0 {
          fatalError("\(fmt): invalid size")
        }
        fmt.removeFirst()
      }
    }
    
    n = (1 << (8 * isize)) - 1
    digits = 0
    while n != 0 {
      digits += 1
      n >>= (fchar == "x") ? 4 : 3
    }
    if fchar == "d" {
      digits += 1
    }
    
    hdfmt =
    "".withCString { a in
      String(fchar).withCString { b in
        ((fchar == "d" || fchar == "u") ? "" : "0").withCString { c in
          cFormat("%lu/%lu \"%*s%%%s%d%s\" \"\\n\"", 16 / isize, isize, (4 * isize - digits), a, c, digits, b )
        }
      }
    }
    odadd(hdfmt)
    
    return fmt
  }
  
  func odadd(_ fmt: String) {
    if needpad {
      add("\"" + PADDING + "\"")
    }
    add(fmt)
    needpad = true
  }
}
