/*
 The MIT License (MIT)
 Copyright © 2024 Robert (r0ml) Lefkowitz

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 and associated documentation files (the “Software”), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
 OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Testing
import testSupport
import Foundation

@Suite class applyTest {

  @Test func regress00() async throws {
    let x = getFile("applyTest", "regress.00", withExtension: "out")
    var res = getFile("applyTest", "regress.00", withExtension: "in")!
    res.removeLast() // get rid of the trailing \n
    let (_, j, _) = try captureStdoutLaunch(Self.self, "apply", ["echo %1 %1 %1 %1", res] )
    #expect( j == x )
  }

  @Test func regress01() async throws {
    let x = sysconf(_SC_ARG_MAX)
    #expect ( x > 0, "sysconf(\(_SC_ARG_MAX)) returned \(x)" )

    let a = String(repeating: "1", count: x / 2)
    let (_, _, e) = try captureStdoutLaunch(Self.self, "apply", ["echo %1 %1 %1", a] )
    #expect( e == "apply: Argument list too long\n" )
  }

}
