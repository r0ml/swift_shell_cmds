
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
import shared

let nl = Int32(Character("\n").asciiValue!)
let spec = ".#-+ 0123456789"

extension hexdump {
  func addfile(_ name: String) throws {
    //   var p: UnsafeMutablePointer<CUnsignedChar>?
    //   var fp: UnsafeMutablePointer<FILE>?
    // var ch: Int32
    
    let buf = try String(contentsOfFile: name, encoding: .utf8).components(separatedBy: "\n")
    for ln in buf {
      let k = ln.trimmingCharacters(in: [" "])
      if k.isEmpty || k.first == "#" { continue }
      add(ln)
    }
  }
  
  func add(_ fmt: String) {
//    var p: UnsafePointer<CUnsignedChar>?
//    var savep: String
    // var nextfs: UnsafeMutablePointer<UnsafeMutablePointer<FS>?>?
    //    var tfs: UnsafeMutablePointer<FS>?
//    var tfu: FU
    
    // start new linked list of format units
    let tfs = FS(fmt: fmt)

    fsArray.append(tfs)

//    nextfu = &tfs?.pointee?.nextfu
    
    // take the format string and break it up into format units
//    p = UnsafePointer<CUnsignedChar>(fmt)

    var p : Substring = Substring("\(fmt)")
    
    while !p.isEmpty {
      // skip leading white space
      p = p.trimmingPrefix { $0.isWhitespace }
      if p.isEmpty { break }
      
      let tfu = FU(fmt: "")
      tfs.fuArray.append(tfu)
      tfu.reps = 1
      
      // if leading digit, repetition count
      if p.first!.isNumber {
        let savep = String(p.prefix { $0.isNumber } )
        p = p.dropFirst(savep.count)
        
        if let k = p.first,
           !(k.isWhitespace || k == "/") {
          badfmt(fmt)
        }
        // may overwrite either white space or slash
        tfu.reps = Int(savep)!
        tfu.flags = .F_SETREP
        // skip trailing white space
        p = p.trimmingPrefix { $0.isWhitespace }
      }
      
      // skip slash and trailing white space
      if p.first == "/" {
        p = p.dropFirst().trimmingPrefix { $0.isWhitespace }
      }
      
      // byte count
      if let k = p.first, k.isNumber {
        let savep = String(p.prefix { $0.isNumber } )
        p = p.dropFirst(savep.count)
        if p.isEmpty || !p.first!.isWhitespace {
            badfmt(fmt)
          }
        tfu.bcnt = Int(savep)!
        
          // skip trailing white space
        p = p.trimmingPrefix { $0.isWhitespace }
      }
      
      // format
      if p.first != "\"" {
        badfmt(fmt)
      }

      let savep = p.dropFirst()
      p = p.dropFirst().trimmingPrefix { $0 != "\"" }
      if p.isEmpty {
        badfmt(fmt)
      }
      let nfmt = savep.dropLast(p.count)

      tfu.fmt = escape( String(nfmt) )
      p = p.dropFirst()
    }
  }
  
  
  func size(fs: FS) -> Int {
//    var fu: UnsafeMutablePointer<FU>?
//    var bcnt: Int,


    // figure out the data block size needed for each format unit

    var cursize: Int = 0
//    var fmt: UnsafeMutablePointer<CUnsignedChar>?
//    var prec: Int32 = 0
    
//    cursize = 0
//    fu = fs.nextfu
    for fu in fs.fuArray {
      if fu.bcnt != 0 {
        cursize += fu.bcnt * fu.reps
        continue
      }
      var bcnt = 0
      var prec = 0
      var fmt = Substring(fu.fmt)
      
      while !fmt.isEmpty {
//      while fmt?.pointee != 0 {a
        
        fmt = fmt.trimmingPrefix { $0 != "%" }.dropFirst()
        if fmt.isEmpty { break }
                     /*
                      * skip any special chars -- save precision in
                      * case it's a %s format.
                      */
        fmt = fmt.trimmingPrefix { spec.dropFirst().contains($0) }

        if fmt.isEmpty {
          badnoconv()
        }
        if fmt.first == ".",
            let sc = String(fmt.dropFirst()).first,
           sc.isNumber {
          let fm = fmt.dropFirst().prefix { $0.isNumber }
          prec = Int(String(fm))!
          fmt = fmt.dropFirst(1+fm.count)
        }
        
        switch fmt.first {
        case "c":
          bcnt += 1
        case "d", "i", "o", "u", "x", "X":
          bcnt += 4
        case "e", "E", "f", "g", "G":
          bcnt += 8
        case "s":
          bcnt += prec
        case "_":
          fmt = fmt.dropFirst()
          switch fmt.first {
          case "c", "p", "u":
            bcnt += 1
          default:
            break
          }
        default:
          break
        }
        
        fmt = fmt.dropFirst()
      }
      cursize += bcnt * fu.reps
    }
    return cursize
  }
  
  func rewrite(fs: FS) {
    enum Sokay {
      case notOkay
      case useBcnt
      case usePrec
    }
    
    var sokay: Sokay
//    var pr: PR?
//    var nextpr: PR?
//    var fu: FU?
//    var p1: UnsafeMutablePointer<UInt8>?
//    var p2: UnsafeMutablePointer<UInt8>?
//    var fmtp: UnsafeMutablePointer<UInt8>?
//    var savech: CChar
    var cs: String = ""
    
    // FIXME: this should do something.
//    var nconv: Int
    var prec: Int = 0
    
    for fu in fs.fuArray {
//      nextpr = fu.nextpr
      var fmtp = Substring(fu.fmt)
      var nconv = 0
      while !fmtp.isEmpty  {
        let pr = PR()
        fu.prArray.append(pr)
//        nextpr = pr
        
        var p1 = fmtp.trimmingPrefix { $0 != "%"}
        
        if p1.isEmpty {
          pr.fmt = String(fmtp)
          pr.flags = prOptions.F_TEXT
          break
        }
        
        if fu.bcnt != 0 {
          sokay = .useBcnt
          p1 = p1.dropFirst().trimmingPrefix { spec.contains($0) }
          if p1.isEmpty {
            badnoconv()
          }
        } else {
          p1 = p1.dropFirst().trimmingPrefix { spec.dropFirst().contains($0 )}
          if p1.isEmpty {
            badnoconv()
          }
          if p1.first == ".",
             let sc = String(p1.dropFirst()).first,
            sc.isNumber {
            sokay = .usePrec
            let px = p1.dropFirst().prefix { $0.isNumber }
            prec = Int(String(px))!
            p1 = p1.dropFirst(1+px.count)
          } else {
            sokay = .notOkay
          }
        }
        
        var p2 = p1.dropFirst()
        cs = String(p1.first!)
        
        switch cs.first {
        case "c":
          pr.flags = prOptions.F_CHAR
          switch fu.bcnt {
          case 0, 1:
            pr.bcnt = 1
          default:
            badcnt( String(p1.first!) )
          }
        case "d", "i":
          pr.flags = prOptions.F_INT
          fallthrough
        case "o", "u", "x", "X":
          pr.flags = prOptions.F_UINT
          cs = "q" + String(cs.first!)
          switch fu.bcnt {
          case 0, 4:
            pr.bcnt = 4
          case 1:
            pr.bcnt = 1
          case 2:
            pr.bcnt = 2
          case 8:
            pr.bcnt = 8
          default:
            badcnt( String(p1.first!) )
          }
        case "e", "E", "f", "g", "G":
          pr.flags = prOptions.F_DBL
          switch fu.bcnt {
          case 0, 8:
            pr.bcnt = 8
          case 4:
            pr.bcnt = 4
          default:
            if fu.bcnt == MemoryLayout<CLong>.size {
              cs = "L" + String(cs.first!)
              pr.bcnt = MemoryLayout<CLong>.size
            } else {
              badcnt(String(p1.first!))
            }
          }
        case "s":
          pr.flags = prOptions.F_STR
          switch sokay {
          case .notOkay:
            badsfmt()
          case .useBcnt:
            pr.bcnt = fu.bcnt
          case .usePrec:
            pr.bcnt = prec
          }
        case "_":
          p2 = p2.dropFirst()
          switch p1.dropFirst().first {
          case "A":
            endfu = fu
            fu.flags = .F_IGNORE
            fallthrough
          case "a":
            pr.flags = prOptions.F_ADDRESS
            p2 = p2.dropFirst()
            switch p1.dropFirst(2).first {
            case "d", "o", "x":
              cs = "q" + String(p1.dropFirst(2).first!)
            default:
              badconv( String(p1.prefix(3)) )
            }
          case "c":
            pr.flags = prOptions.F_C
            /* cs[0] = 'c';  set in conv_c */
//            cs = "c"
            switch fu.bcnt {
            case 0, 1:
              pr.bcnt = 1
            default:
              badcnt(String(p1.prefix(2)))
            }
          case "p":
            pr.flags = prOptions.F_P
            cs = "c"
            switch fu.bcnt {
            case 0, 1:
              pr.bcnt = 1
            default:
              badcnt(String(p1.prefix(2)))
            }
          case "u":
            pr.flags = prOptions.F_U
            /* cs[0] = 'c';  set in conv_u */
//            cs = "c"
            switch fu.bcnt {
            case 0, 1:
              pr.bcnt = 1
            default:
              badcnt(String(p1.prefix(2)))
            }
          case "n":
            endfu = fu
            fu.flags = .F_IGNORE
            pr.flags = prOptions.F_TEXT
            fmtp = "\n"
            cs = ""
          default:
            badconv(String(p1.prefix(2)))
          }
        default:
          badconv(String(p1.prefix(2)))
        }
        
        pr.fmt = "\(String(fmtp.prefix(fmtp.count - p1.count)))\(cs)"

        pr.cchar = pr.fmt.index(pr.fmt.startIndex, offsetBy: fmtp.count - p1.count)
        fmtp = p2
        
        if !(pr.flags == prOptions.F_ADDRESS) && fu.bcnt != 0 {
          nconv += 1
          if nconv > 1 {
            errx(1, "byte count with multiple conversion characters")
          }
        }
      }
      
      if fu.bcnt == 0 {
        for pr in fu.prArray {
          fu.bcnt += pr.bcnt
        }
      }
    }
    
    for (nn, fu) in fs.fuArray.enumerated() {
      if nn == fs.fuArray.count - 1 && fs.bcnt < blocksize && !(fu.flags == .F_SETREP ) && fu.bcnt != 0 {
        fu.reps += (blocksize - fs.bcnt) / fu.bcnt
      }
      if fu.reps > 1 {
        let pr = fu.prArray.last!
        
        if pr.fmt.last!.isWhitespace {
          //        let ns = pr.fmt.lastIndex { $0.isWhitespace }
          pr.nospace = true
        }
      }
    }
  }
  
  // replace escape sequences in formats
  func escape(_ p1: String) -> String {
    var res = ""
    var wasSlash = false
    for p2 in p1 {
      if wasSlash {
        wasSlash.toggle()
        switch p2 {
        case "a":
          res.append("\u{7}")
        case "b":
          res.append("\u{8}")  // backspace
        case "f":
          res.append("\u{c}") // form - feed (page break)
        case "n":
          res.append("\n")
        case "r":
          res.append("\r")
        case "t":
          res.append("\t")
        case "v":
          res.append("\u{b}") // vertical tab
        default:
          res.append(p2)
        }
      } else {
        if p2 == "\\" {
          wasSlash.toggle()
        } else {
          res.append(p2)
        }
      }
    }
    if wasSlash {
      res.append("\\")
    }
    return res
  }
  
  func badcnt(_ s: String) {
    errx(1, "\(s): bad byte count")
  }
  
  func badsfmt() {
    errx(1, "%%s: requires a precision or a byte count")
  }
  
  func badfmt(_ fmt: String) {
    errx(1, "\"\(fmt)\": bad format")
  }
  
  func badconv(_ ch: String) {
    errx(1, "%%\(ch): bad conversion character")
  }
  
  func badnoconv() {
    errx(1, "missing conversion character")
  }
}
