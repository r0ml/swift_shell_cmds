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
    let td = FileManager.default.temporaryDirectory.path(percentEncoded: false)
    let tdx = "\(td)/empty.XXXXXXXX"
    try FileManager.default.createDirectory(atPath: tdx, withIntermediateDirectories: true)
    
    let ex = "PATH=\"\"; export PATH;\n"
    try await run(output: ex, env: ["PATH":"", "PATH_HELPER_ROOT":tdx, "MANPATH":""] )
  }

  @Test("empty PATH and MANPATH") func empty2() async throws {
    let td = FileManager.default.temporaryDirectory.path(percentEncoded: false)
    let tdx = "\(td)/empty2.XXXXXXXX"
    try FileManager.default.createDirectory(atPath: tdx, withIntermediateDirectories: true)
    
    let pp = "PATH=\"\"; export PATH;\n"
    let mp = "MANPATH=\":\"; export MANPATH;\n"
    
    
    try await run(output: pp + mp, env: ["PATH":"", "PATH_HELPER_ROOT":tdx, "MANPATH":""] )
  }
  
  @Test("preserve existing values") func preserve() async throws {
    let td = FileManager.default.temporaryDirectory.path(percentEncoded: false)
    let tdx = "\(td)/preserve.XXXXXXXX"
    try FileManager.default.createDirectory(atPath: tdx, withIntermediateDirectories: true)
    
    let res = """
PATH="a:b"; export PATH;
MANPATH="c:d:"; export MANPATH;

"""
    
    try await run(output: res, env: ["PATH":"a:b", "PATH_HELPER_ROOT":tdx, "MANPATH":"c:d"] )
  }
  
  @Test("combine defaults and add-ons in that order") func combine() async throws {
    let td = FileManager.default.temporaryDirectory.path(percentEncoded: false)
    let tdx = "\(td)/combine.XXXXXXXX"
    let tdxx = "\(tdx)/etc/paths.d"
    try FileManager.default.createDirectory(atPath: tdxx, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths", contents: Data("a\nb\n".utf8) )
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/add-ons", contents: Data("c\nd\n".utf8) )

    
    let res = "PATH=\"a:b:c:d\"; export PATH;\n"
    
    try await run(output: res, env: [ "PATH_HELPER_ROOT":tdx, "PATH":"" ] )
  }
  
  @Test("read add-ons in correct order") func order() async throws {
    let td = FileManager.default.temporaryDirectory.path(percentEncoded: false)
    let tdx = "\(td)/order.XXXXXXXX"
    let tdxx = "\(tdx)/etc/paths.d"
    try FileManager.default.createDirectory(atPath: tdxx, withIntermediateDirectories: true)
    print(tdxx)
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths", contents: Data("a\nb\n".utf8) )
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/a", contents: Data("z\n".utf8) )
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/1000", contents: Data("y\n".utf8) )
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/0400-b", contents: Data("x\n".utf8) )
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/400-a", contents: Data("w\n".utf8) )
    
    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/70def", contents: Data("d\ne\nf\n".utf8) )

    FileManager.default.createFile(atPath: "\(tdx)/etc/paths.d/9", contents: Data("c\n".utf8) )
    
    let res = "PATH=\"a:b:c:d:e:f:w:x:y:z:g:h\"; export PATH;\n"
    
    try await run(output: res, env: [ "PATH_HELPER_ROOT":tdx, "PATH":"g:h" ] )
  }
  
  
  
}
