
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 1995 Wolfram Schneider <wosch@FreeBSD.org>. Berlin.
 * Copyright (c) 1989, 1993
 *  The Regents of the University of California.  All rights reserved.
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
 *  This product includes software developed by the University of
 *  California, Berkeley and its contributors.
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


let ASCII_MAX = SCHAR_MAX
let ASCII_MIN = 32
let LOCATE_REG = "*?[]\\"

func check_bigram_char(_ ch: UInt8) -> UInt8 {
    if ch == 0 || (ch >= ASCII_MIN && ch <= ASCII_MAX) {
        return ch
    }

    fatalError("locate database header corrupt, bigram char outside 0, \(ASCII_MIN)-\(ASCII_MAX): \(ch)")
}

/* split a colon separated string into a char vector
 *
 * "bla:foo" -> {"foo", "bla"}
 * "bla:"    -> {"foo", dot}
 * "bla"     -> {"bla"}
 * ""       -> do nothing
 *
 */
func colon(path: String, dot: String) -> [String] {
  return path.isEmpty ? [] : path.components(separatedBy: ":")
}

/*
func colon(dbv: [String]?, path: String, dot: String) -> [String] {
    var dbv = dbv
    var vlen: Int
    var slen: Int
    var c: String.Index
    var ch: String.Index
    var p: String

    if dbv == nil {
        dbv = []
    }

    if path.isEmpty {
        print("empty database name, ignored")
        return dbv!
    }

    vlen = dbv!.count

    ch = path.startIndex
    c = path.startIndex
    while true {
        if path[ch] == ":" || (!path[ch].isEmpty && !(path[ch - 1] == ":" && ch == path.index(after: path.startIndex))) {
            if ch == c {
                p = dot
            } else {
                slen = path.distance(from: c, to: ch)
                p = String(path[c..<ch])
            }
            dbv!.append(p)
            c = path.index(after: ch)
        }
        if path[ch].isEmpty {
            break
        }
        ch = path.index(after: ch)
    }
    return dbv!
}
*/

func printMatches(counter: UInt) {
    print("\(counter)")
}

/*
 * extract last glob-free subpattern in name for fast pre-match; prepend
 * '\0' for backwards match; return end of new pattern
 */
func patprep(name: String) -> String {
    var endmark: String.Index
    var p: String.Index
    var subp: String.Index

    var globfree = String(repeating: "\0", count: 100)
    subp = globfree.startIndex
    globfree[subp] = "\0"
    p = name.index(before: name.endIndex)

    while p >= name.startIndex {
        if LOCATE_REG.contains(name[p]) {
            break
        }
        p = name.index(before: p)
    }

    if p >= name.startIndex && (name[p...].contains("[") || name[p...].contains("]")) {
        for p in name.indices {
            if name[p] == "]" || name[p] == "[" {
                break
            }
        }
        p = name.index(before: p)

        if p >= name.startIndex && LOCATE_REG.contains(name[p]) {
            p = name.index(before: name.startIndex)
        }
    }

    if p < name.startIndex {
        globfree.append("/")
    } else {
        endmark = p
        while p >= name.startIndex {
            if LOCATE_REG.contains(name[p]) {
                break
            }
            p = name.index(before: p)
        }
        for p in p...endmark {
            globfree.append(name[p])
        }
    }
    globfree.append("\0")
    return String(globfree.dropLast())
}

func tolower_word(word: String) -> String {
    return word.lowercased()
}

func getwm(p: UnsafeMutableRawPointer) -> Int {
    var i: Int
    var hi: Int

    i = p.load(as: Int.self)

    if i > MAXPATHLEN || i < -(MAXPATHLEN) {
        hi = Int(bigEndian: i)
        if hi > MAXPATHLEN || hi < -(MAXPATHLEN) {
            fatalError("integer out of +-MAXPATHLEN (\(MAXPATHLEN)): \(abs(i) < abs(hi) ? i : hi)")
        }
        return hi
    }
    return i
}

func getwf(_ fp: UnsafeMutablePointer<FILE>) -> Int {
    let word = Int(getw(fp))

    if word > MAXPATHLEN || word < -(MAXPATHLEN) {
        let hword = Int(bigEndian: word )
        if hword > MAXPATHLEN || hword < -(MAXPATHLEN) {
            fatalError("integer out of +-MAXPATHLEN (\(MAXPATHLEN)): \(abs(word) < abs(hword) ? word : hword)")
        }
        return hword
    }
    return word
}
