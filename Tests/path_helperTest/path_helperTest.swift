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

@Suite("path_helper", .serialized) final class path_helperTest : ShellTest {
  let cmd = "path_helper"
  let suiteBundle = "shell_cmds_path_helperTest"
  
  @Test("empty PATH") func empty() async throws {
    let tdx = try tmpdir("empty")
    let ex = "PATH=\"\"; export PATH;\nMANPATH=\":\"; export MANPATH;\n"
    try await run(output: ex, env: ["PATH":"", "PATH_HELPER_ROOT":tdx.string, "MANPATH":""] )
  }

  @Test("empty PATH and MANPATH") func empty2() async throws {
    let tdx = try tmpdir("empty2")
    defer { rm(tdx) }

    let pp = "PATH=\"\"; export PATH;\n"
    let mp = "MANPATH=\":\"; export MANPATH;\n"

    try await run(output: pp + mp, env: ["PATH":"", "PATH_HELPER_ROOT":tdx.string, "MANPATH":""] )
  }
  
  @Test("preserve existing values") func preserve() async throws {
    let tdx = try tmpdir("preserve")
    defer { rm(tdx) }

    let res = """
PATH="a:b"; export PATH;
MANPATH="c:d:"; export MANPATH;

"""
    try await run(output: res, env: ["PATH":"a:b", "PATH_HELPER_ROOT":tdx.string, "MANPATH":"c:d"] )
  }
  
  // FIXME: doesn't pass when run from command line, but passes when run from XCode
  @Test("combine defaults and add-ons in that order") func combine() async throws {
    let tdx = try tmpdir("combine")
    defer { rm(tdx) }

    let tdxx = try tmpdir("combine/etc/paths.d")
    let a = try tmpfile("combine/etc/paths", "a\nb\n" )
    let b = try tmpfile("combind/etc/paths.d/add-ons", "c\nd\n" )
    let res = "PATH=\"a:b:c:d\"; export PATH;\n"
    try await run(output: res, env: [ "PATH_HELPER_ROOT":tdx.string, "PATH":"" ] )
  }

  // FIXME: doesn't pass when run from command line, but passes when run from XCode
  @Test("read add-ons in correct order") func order() async throws {
    let tdx = try tmpdir("order")
    defer { rm(tdx) }

    let tdxx = try tmpdir("order/etc/paths.d")

    let a = try tmpfile("order/etc/paths", "a\nb\n" )
    let b = try tmpfile("order/etc/paths.d/a", "z\n" )
    let c = try tmpfile("order/etc/paths.d/1000", "y\n" )
    let d = try tmpfile("order/etc/paths.d/0400-b", "x\n" )
    let e = try tmpfile("order/etc/paths.d/400-a", "w\n" )
    let f = try tmpfile("order/etc/paths.d/70def", "d\ne\nf\n" )
    let g = try tmpfile("order/etc/paths.d/9", "c\n" )

    let res = "PATH=\"a:b:c:d:e:f:w:x:y:z:g:h\"; export PATH;\n"
    
    try await run(output: res, env: [ "PATH_HELPER_ROOT": tdx.string, "PATH":"g:h" ] )

  }
  
  
  
}
