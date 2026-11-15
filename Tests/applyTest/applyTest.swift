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

import ShellTesting

@Suite class applyTest : ShellTest {
  let cmd = "apply"
  let suiteBundle = "shell_cmds_applyTest"

  @Test func regress00() async throws {

    //    print(packageRoot() )
    //    print(currentTestModule())

    let x = try fileContents("regress.00.out")
    var res = try fileContents("regress.00.in")
    res.removeLast() // get rid of the trailing \n
    try await run( output: x, args: "echo %1 %1 %1 %1", res )
  }

  @Test func regress01() async throws {
    let x = Sysconf.scArgMax
    #expect ( x > 0, "sysconf(_SC_ARG_MAX) returned \(x)" )

    let a = String(repeating: "1", count: x / 2)
    try await run(status: 1, error: /Argument list too long/, args: "echo %1 %1 %1", a )
  }

  @Test func tooFewArguments() async throws {
    // Test simple substitution with one argument
    let input = "hello world\n"
    try await run(status: 1, error: /expecting additional argument after/, args: "echo %1 %2", input)
  }

  @Test func basicSubstitution() async throws {
    // Test applying command to multiple arguments
    let input = "hello"
    let expected = "hello hello"
    try await run(output: expected, args: "echo -n %1 %1 ", input)
  }

  @Test func customMagicCharacter() async throws {
    // Test using custom magic character with -a flag
    let input = "test"
    let expected = "test test\n"
    try await run(output: expected, args: "-a", "@", "echo @1 @1", input)
  }

  @Test func debugMode() async throws {
    // Test debug mode output
    let expected = "exec echo arg1 arg2\n"
    try await run(output: expected, args: "-d", "echo %1 %2", "arg1", "arg2")
  }

  @Test func argumentCountIgnored() async throws {
    // Test with specific argument count
    let expected = "first second third\n"
    try await run(output: expected, args: "-3", "echo %1 %2 %3", "first", "second", "third")
  }

  @Test func argumentCount() async throws {
    // Test with specific argument count
    let expected = "first second third\n"
    try await run(output: expected, args: "-3", "echo", "first", "second", "third")
  }

  @Test func arguments() async throws {
    // Test with specific argument count
    let expected = "first\nsecond\nthird\n"
    try await run(output: expected, args: "echo", "first", "second", "third")
  }

  @Test func zeroCountRunsCommandOncePerArgumentWithoutAppending() async throws {
    // -0 must not append %1, and must not crash building the command
    try await run(output: "exec echo\nexec echo\n", args: "-d", "-0", "echo", "a", "b")
  }

  @Test func debugGroupsArguments() async throws {
    try await run(output: "exec echo a b\nexec echo c d\n", args: "-d", "-2", "echo", "a", "b", "c", "d")
  }

  @Test(arguments: [".", "$", "(", ")", "*", "+", "?", "[", "]", "{", "}", "|", "^", "\\"])
  func regexMetacharacterAsMagic(_ m: String) async throws {
    try await run(output: "exec echo x\n", args: "-d", "-a", m, "echo \(m)1", "x")
  }

  @Test func metacharacterMagicDoesNotMatchOtherCharacters() async throws {
    // with "." as magic, "a1" is not a reference
    try await run(output: "exec echo a1 x\n", args: "-d", "-a", ".", "echo a1 .1", "x")
  }

  @Test func zeroIsNotAMagicDigit() async throws {
    try await run(output: "%0 x\n", args: "echo %0 %1", "x")
  }

  @Test func commandFailureYieldsStatusOne() async throws {
    try await run(status: 1, args: "false", "x")
  }

  @Test func laterFailureIsNotMasked() async throws {
    // first invocation fails, last succeeds; overall status is still 1
    try await run(status: 1, args: "test %1 = a", "b", "a")
  }

  @Test func multipleCountOptionsRejected() async throws {
    try await run(status: 1, error: /only one -# argument may be specified/, args: "-1", "-2", "echo", "a")
  }

  @Test func multiCharacterMagicRejected() async throws {
    try await run(status: 1, error: /illegal magic character specification/, args: "-a", "ab", "echo", "x")
  }

  @Test func emptyMagicRejected() async throws {
    try await run(status: 1, error: /illegal magic character specification/, args: "-a", "", "echo", "x")
  }

  @Test func missingArgumentsPrintsUsage() async throws {
    try await run(status: 1, error: /usage: apply/, args: "echo")
  }

  @Test func unknownOptionPrintsUsage() async throws {
    try await run(status: 1, error: /usage: apply/, args: "-z", "echo", "x")
  }

  @Test func leftoverArgumentSingular() async throws {
    try await run(status: 1, error: /expecting additional argument after "c"/, args: "-2", "echo", "a", "b", "c")
  }

  @Test func leftoverArgumentPlural() async throws {
    try await run(status: 1, error: /expecting additional arguments after "a"/, args: "-3", "echo", "a")
  }

  @Test func argumentLimitCountsBytesNotCharacters() async throws {
    // 2-byte characters: fewer than ARG_MAX characters but more than ARG_MAX bytes once substituted
    let a = String(repeating: "é", count: Sysconf.scArgMax / 3)
    try await run(status: 1, error: /Argument list too long/, args: "echo %1 %1", a)
  }
}
