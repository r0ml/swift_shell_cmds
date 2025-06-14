
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024 using ChatGPT
// from a file containing the following notice:

/*
 * SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 *
 * Copyright (c) 2005  - Garance Alistair Drosehn <gad@FreeBSD.org>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of the FreeBSD Project.
 */

import CMigration

extension Env {
   
    /*
     * The is*() routines take a parameter of 'Int', but expect values in the range
     * of unsigned char.  Define some wrappers which take a value of type 'Character',
     * whether signed or unsigned, and ensure the value ends up in the right range.
     */
    /*
     func isalnumch(_ anyChar: Character) -> Bool {
     return isalnum(UInt8(anyChar.asciiValue ?? 0))
     }
     
     func isalphach(_ anyChar: Character) -> Bool {
     return isalpha(UInt8(anyChar.asciiValue ?? 0))
     }
     
     func isspacech(_ anyChar: Character) -> Bool {
     return isspace(UInt8(anyChar.asciiValue ?? 0))
     }
     */
    
    /*
     * Routine to determine if a given fully-qualified filename is executable.
     * This is copied almost verbatim from FreeBSD's usr.bin/which/which.c.
     */
    func is_there(_ candidate: String) -> Bool {
      var fin = Darwin.stat()
        
        /* XXX work around access(2) false positives for superuser */
        if access(candidate, X_OK) == 0 &&
            // FIXME: Darwin.stat is ambiguous
            stat(candidate, &fin) == 0 &&
            S_ISREG(fin.st_mode) &&
            (Darwin.getuid() != 0 ||
             (fin.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) != 0) {
            if env_verbosity > 1 {
              Darwin.fputs("#env   matched:\t'\(candidate)'\n", Darwin.stderr)
            }
            return true
        }
        return false
    }
    
    /**
     * Routine to search through an alternate path-list, looking for a given
     * filename to execute.  If the file is found, replace the original
     * unqualified name with a fully-qualified path.  This allows `env' to
     * execute programs from a specific strict list of possible paths, without
     * changing the value of PATH seen by the program which will be executed.
     * E.G.:
     *  #!/usr/bin/env -S-P/usr/local/bin:/usr/bin perl
     * will execute /usr/local/bin/perl or /usr/bin/perl (whichever is found
     * first), no matter what the current value of PATH is, and without
     * changing the value of PATH that the script will see when it runs.
     *
     * This is similar to the print_matches() routine in usr.bin/which/which.c.
     */
    func search_paths(_ path: String, _ argv: String) -> String {
        //    var candidate = [CChar](repeating: 0, count: Int(PATH_MAX))
        //    var d: String?
        let filename = argv
        var fqname: String?
        
        /* If the file has a `/' in it, then no search is done */
        if filename.contains("/") {
            return filename
        }
        
        if env_verbosity > 1 {
          Darwin.fputs("#env Searching:\t'\(path)'\n", Darwin.stderr)
          Darwin.fputs("#env  for file:\t'\(filename)'\n", Darwin.stderr)
        }
        
        fqname = nil
        while let pathComponent = path.split(separator: ":").first {
            var d = pathComponent
            if d.isEmpty {
                d = "."
            }
            let candidate = "\(d)/\(filename)"
            if is_there(candidate) {
                fqname = candidate
                break
            }
        }
        
        if fqname == nil {
          errno = Darwin.ENOENT
            err(127, filename)
        }
        return fqname!
    }
    
    /**
     * Routine to split a string into multiple parameters, while recognizing a
     * few special characters.  It recognizes both single and double-quoted
     * strings.  This processing is designed entirely for the benefit of the
     * parsing of "#!"-lines (aka "shebang" lines == the first line of an
     * executable script).  Different operating systems parse that line in very
     * different ways, and this split-on-spaces processing is meant to provide
     * ways to specify arbitrary arguments on that line, no matter how the OS
     * parses it.
     *
     * Within a single-quoted string, the two characters "\'" are treated as
     * a literal "'" character to add to the string, and "\\" are treated as
     * a literal "\" character to add.  Other than that, all characters are
     * copied until the processing gets to a terminating "'".
     *
     * Within a double-quoted string, many more "\"-style escape sequences
     * are recognized, mostly copied from what is recognized in the `printf'
     * command.  Some OS's will not allow a literal blank character to be
     * included in the one argument that they recognize on a shebang-line,
     * so a few additional escape-sequences are defined to provide ways to
     * specify blanks.
     *
     * Within a double-quoted string "\_" is turned into a literal blank.
     * (Inside of a single-quoted string, the two characters are just copied)
     * Outside of a quoted string, "\_" is treated as both a blank, and the
     * end of the current argument.  So with a shelbang-line of:
     *    #!/usr/bin/env -SA=avalue\_perl
     * the -S value would be broken up into arguments "A=avalue" and "perl".
     *
     * Returns the new "arguments" to be used instead of the original CommandLine arguments
     */
    
    // FIXME: figure out how to put this back
    /*
     func splitSpaces(_ str: String, _ origind: inout Int32 /*, _ origc: inout Int, _ origv: inout [String] */)
     -> [String] {
     let nullarg = ""
     var bq_src: String?, copystr: String?, src: String
     var dest: String, newargv: [String], newstr: String, nextarg: [String], oldarg: [String]
     var addcount, bq_destlen, copychar, found_sep, in_arg, in_dq, in_sq: Int
     
     while str.first?.isWhitespace == true {
     str.removeFirst()
     }
     if str.isEmpty {
     return
     }
     newstr = str
     
     newargv = Array(repeating: "", count: origc + (str.count / 2) + 2)
     nextarg = newargv
     nextarg.append(origv[0])
     
     addcount = 0
     bq_destlen = 0
     in_arg = 0
     in_dq = 0
     in_sq = 0
     bq_src = nil
     
     for char in str {
     copychar = 0
     found_sep = 0
     copystr = nil
     
     switch char {
     case "\"":
     if in_sq == 1 {
     copychar = char
     } else if in_dq == 1 {
     in_dq = 0
     } else {
     copystr = nullarg
     in_dq = 1
     bq_destlen = dest.count - nextarg.last!.count
     bq_src = String(char)
     }
     case "$":
     if in_sq == 1 {
     copychar = char
     } else {
     copystr = expandVars(in_arg, nextarg.last!, &dest, &src)
     }
     case "'":
     if in_dq == 1 {
     copychar = char
     } else if in_sq == 1 {
     in_sq = 0
     } else {
     copystr = nullarg
     in_sq = 1
     bq_destlen = dest.count - nextarg.last!.count
     bq_src = String(char)
     }
     case "\\":
     if in_sq == 1 {
     copychar = str[str.index(after: str.startIndex)]
     if copychar == "'" || copychar == "\\" {
     str.removeFirst()
     } else {
     copychar = char
     }
     } else {
     str.removeFirst()
     switch str.first {
     case "\"", "#", "$", "'", "\\":
     copychar = char
     case "_":
     if in_dq == 1 {
     copychar = " "
     } else {
     found_sep = 1
     str.removeFirst()
     }
     case "c":
     if in_dq == 1 {
     fatalError("Sequence '\\\(str.first!)' is not allowed in quoted strings")
     }
     break
     case "f":
     copychar = "\u{000C}"
     case "n":
     copychar = "\n"
     case "r":
     copychar = "\r"
     case "t":
     copychar = "\t"
     case "v":
     copychar = "\u{000B}"
     default:
     if str.first?.isWhitespace == true {
     copychar = char
     } else {
     fatalError("Invalid sequence '\\\(str.first!)' in -S")
     }
     }
     }
     default:
     if (in_dq == 1 || in_sq == 1) && in_arg == 1 {
     copychar = char
     } else if char.isWhitespace {
     found_sep = 1
     } else {
     if !in_arg && char == "#" {
     break
     }
     copychar = char
     }
     }
     
     if copychar != 0 || copystr != nil {
     if in_arg == 0 {
     nextarg.append(dest)
     addcount += 1
     in_arg = 1
     }
     if copychar != 0 {
     dest.append(Character(UnicodeScalar(copychar)!))
     } else if let copy = copystr {
     dest.append(contentsOf: copy)
     }
     } else if found_sep == 1 {
     dest.append("\0")
     while str.first?.isWhitespace == true {
     str.removeFirst()
     }
     str = String(str.dropLast())
     in_arg = 0
     }
     }
     
     dest.append("\0")
     nextarg.append(nil)
     
     if in_dq == 1 || in_sq == 1 {
     fatalError("No terminating quote for string: \(bq_destlen)\(nextarg.last!)\(bq_src!)")
     }
     
     if env_verbosity > 1 {
     print("#env  split -S:\t'\(str)'")
     oldarg = Array(newargv[1...])
     print("#env      into:\t'\(oldarg[0])'")
     for i in 1..<oldarg.count {
     print("#env          &\t'\(oldarg[i])'")
     }
     }
     
     for i in origv[origind...] {
     nextarg.append(i)
     }
     nextarg.append(nil)
     
     origc += addcount - origind + 1
     origv = newargv
     origind = 1
     }
     */
    
    /**
     * Routine to split expand any environment variables referenced in the string
     * that -S is processing.  For now it only supports the form ${VARNAME}.  It
     * explicitly does not support $VARNAME, and obviously can not handle special
     * shell-variables such as $?, $*, $1, etc.  It is called with *src_p pointing
     * at the initial '$', and if successful it will update *src_p, *dest_p, and
     * possibly *thisarg_p in the calling routine.
     */
    
    // FIXME: figure out how to put me back
    /*
     func expandVars(in inThisarg: Int, thisargP: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>, destP: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>, srcP: UnsafeMutablePointer<UnsafePointer<Int8>?>) -> String? {
     var vbegin: UnsafePointer<Int8>?
     var vend: UnsafePointer<Int8>?
     var vvalue: UnsafePointer<Int8>?
     var newstr: UnsafeMutablePointer<Int8>?
     var vname: UnsafeMutablePointer<Int8>?
     var badReference: Int
     var namelen: Int
     var newlen: Int
     
     badReference = 1
     vbegin = srcP.pointee! + 1
     vend = vbegin
     if vbegin!.pointee == 123 { // ASCII value for '{'
     if vbegin!.advanced(by: 1).pointee == 95 || isalphach(vbegin!.advanced(by: 1).pointee) {
     vend = vbegin!.advanced(by: 1)
     while vend!.pointee == 95 || isalnumch(vend!.pointee) {
     vend = vend!.advanced(by: 1)
     }
     if vend!.pointee == 125 { // ASCII value for '}'
     badReference = 0
     }
     }
     }
     if badReference != 0 {
     errx(1, "Only ${VARNAME} expansion is supported, error at: %s", srcP.pointee!)
     }
     
     srcP.pointee = vend
     namelen = Int(vend! - vbegin! + 1)
     vname = UnsafeMutablePointer<Int8>.allocate(capacity: namelen)
     vname!.initialize(from: vbegin!, count: namelen)
     vvalue = getenv(vname)
     if vvalue == nil || vvalue!.pointee == 0 {
     if env_verbosity > 2 {
     fprintf(stderr, "#env  replacing ${%s} with null string\n", vname)
     }
     vname!.deallocate()
     return nil
     }
     
     if env_verbosity > 2 {
     fprintf(stderr, "#env  expanding ${%s} into '%s'\n", vname, vvalue)
     }
     
     if strlen(vname) + 3 >= strlen(vvalue) {
     vname!.deallocate()
     return String(cString: vvalue!)
     }
     
     newlen = Int(strlen(vvalue) + strlen(srcP.pointee!) + 1)
     if inThisarg != 0 {
     destP.pointee!.pointee = 0
     newlen += Int(strlen(thisargP.pointee!))
     newstr = UnsafeMutablePointer<Int8>.allocate(capacity: newlen)
     newstr!.initialize(from: thisargP.pointee!, count: Int(strlen(thisargP.pointee!)))
     thisargP.pointee = newstr
     } else {
     newstr = UnsafeMutablePointer<Int8>.allocate(capacity: newlen)
     newstr!.pointee = 0
     }
     destP.pointee = strchr(newstr, 0)
     vname!.deallocate()
     return String(cString: vvalue!)
     }
     */
    
    
}
