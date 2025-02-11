
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 1995 Wolfram Schneider <wosch@FreeBSD.org>. Berlin.
 * Copyright (c) 1989, 1993
 *      The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * James A. Woods.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the University of
 *      California, Berkeley and its contributors.
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
 *
 * $FreeBSD$
 */

import Foundation

let NBG = 128    /* number of bigrams considered */
let OFFSET = 14    /* abs value of max likely diff */
let PARITY = 0200    /* parity bit */
let SWITCH = 30    /* switch code */
let UMLAUT = 31              /* an 8 bit char followed */

/*   0-28  likeliest differential counts + offset to make nonnegative */
let LDC_MIN = 0
let LDC_MAX = 28

let UCHAR_MAX = SCHAR_MAX * 2 + 1


nonisolated(unsafe) var myctype : [UInt8] = Array(repeating: 0, count: Int(UCHAR_MAX) + 1);


let TOLOWER = myctype

func TO7BIT(_ x : Int32) -> UInt8 { return UInt8(x & SCHAR_MAX) }

extension locate {
  func statistic(fp: UnsafeMutablePointer<FILE>, path_fcodes: UnsafeMutablePointer<Int8>) {
    var lines, chars, size, big, zwerg: Int
    var p, s: UnsafeMutablePointer<UInt8>
    var count, umlaut: Int
    var bigram1 = [UInt8](repeating: 0, count: NBG)
    var bigram2 = [UInt8](repeating: 0, count: NBG)
    var path = [UInt8](repeating: 0, count: Int(MAXPATHLEN) )
    
    for c in 0..<NBG {
      bigram1[c] = check_bigram_char(UInt8(getc(fp)))
      bigram2[c] = check_bigram_char(UInt8(getc(fp)))
    }
    
    lines = 0
    chars = 0
    big = 0
    zwerg = 0
    umlaut = 0
    size = NBG + NBG
    
    var c = getc(fp)
    count = 0
    while c != EOF {
      if c == SWITCH {
        count += getwf(fp) - OFFSET
        size += MemoryLayout<Int>.size
        zwerg += 1
      } else {
        count += Int(c) - OFFSET
      }
      
      p = path + count
      while true {
        c = getc(fp)
        if c <= SWITCH { break }
        
        size += 1
        if c < PARITY {
          if c == UMLAUT {
            c = getc(fp)
            size += 1
            umlaut += 1
          }
          p += 1
        } else {
          big += 1
          p += 2
        }
      }
      
      p += 1
      lines += 1
      chars += (p - path)
    }
    
    print("Database: \(String(cString: path_fcodes))")
    print("Compression: Front: \(Float(size + big - (2 * NBG)) / Float(chars / 100))%, ")
    print("Bigram: \(Float(size - big) / Float(size / 100))%, ")
    print("Total: \(Float(size - (2 * NBG)) / Float(chars / 100))%")
    print("Filenames: \(lines), ")
    print("Characters: \(chars), ")
    print("Database size: \(size)")
    print("Bigram characters: \(big), ")
    print("Integers: \(zwerg), ")
    print("8-Bit characters: \(umlaut)")
  }
  
  
  
  
  func fastfind(fp: UnsafeMutablePointer<FILE>, pathpart: UnsafeMutablePointer<Int8>, database: UnsafeMutablePointer<Int8>) {
    
    var p, s, patend, q, foundchar: UnsafeMutablePointer<UInt8>
    var c, cc: Int
    var count, found, globflag: Int
    var cutoff: UnsafeMutablePointer<UInt8>
    var bigram1 = [UInt8](repeating: 0, count: NBG)
    var bigram2 = [UInt8](repeating: 0, count: NBG)
    var path = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
    
    tolower_word(pathpart)
    
    for c in 0..<NBG {
      bigram1[c] = check_bigram_char(UInt8(getc(fp)))
      bigram2[c] = check_bigram_char(UInt8(getc(fp)))
    }
    
    p = pathpart
    while p.pointee != 0 {
      if strchr(LOCATE_REG, Int32(p.pointee)) != nil {
        break
      }
      p = p.advanced(by: 1)
    }
    
    globflag = p.pointee == 0 ? 0 : 1
    
    p = pathpart
    patend = patprep(p)
    cc = Int(patend.pointee)
    
    var table = [UInt8](repeating: 0, count: Int(UCHAR_MAX + 1))
    table[Int(TOLOWER(patend.pointee))] = 1
    table[Int(toupper(Int32(patend.pointee)))] = 1
    
    found = 0
    count = 0
    foundchar = nil
    
    c = Int(getc(fp))
    while c != EOF {
      if c == SWITCH {
        count += getwf(fp) - OFFSET
      } else {
        count += c - OFFSET
      }
      
      if count < 0 || count > MAXPATHLEN {
        fatalError("corrupted database: \(String(cString: database))")
      }
      
      p = path + count
      foundchar = p - 1
      
      while true {
        c = Int(getc(fp))
        if c < PARITY {
          if c <= UMLAUT {
            if c == UMLAUT {
              c = Int(getc(fp))
            } else {
              break
            }
          }
          if table[c] != 0 {
            foundchar = p
          }
          p.pointee = UInt8(c)
          p = p.advanced(by: 1)
        } else {
          c = Int(TO7BIT(Int32(c) ))
          if table[Int(bigram1[c]) ] != 0 || table[ Int(bigram2[c]) ] != 0 {
            foundchar = p + 1
          }
          p.pointee = bigram1[c]
          p = p.advanced(by: 1)
          p.pointee = bigram2[c]
          p = p.advanced(by: 1)
        }
      }
      
      if found != 0 {
        cutoff = path
        p.pointee = 0
        p = p.advanced(by: -1)
        foundchar = p
      } else if foundchar! >= path + count {
        p.pointee = 0
        p = p.advanced(by: -1)
        cutoff = path + count
      } else {
        continue
      }
      
      found = 0
      s = foundchar
      while s! >= cutoff {
        if s.pointee == UInt8(cc) || TOLOWER(s.pointee) == UInt8(cc) {
          p = patend - 1
          q = s - 1
          while p.pointee != 0 {
            if q.pointee != p.pointee && TOLOWER(q.pointee) != p.pointee {
              break
            }
            p = p.advanced(by: -1)
            q = q.advanced(by: -1)
          }
          if p.pointee == 0 {
            found = 1
            if !globflag || fnmatch(pathpart, path, 0) == 0 {
              if f_silent {
                counter += 1
              } else if f_limit {
                counter += 1
                if f_limit >= counter {
                  print("\(String(cString: path))\(separator)")
                } else {
                  fatalError("[show only \(counter - 1) lines]")
                }
              } else {
                print("\(String(cString: path))\(separator)")
              }
            }
            break
          }
        }
        s = s?.advanced(by: -1)
      }
    }
  }
}
