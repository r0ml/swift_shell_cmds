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
import Darwin

@Suite("script") struct scriptTest : ShellTest {
  let cmd = "script"
  let suiteBundle = "shell_cmds_scriptTest"

  @Test("Ignore tcgetattr() failure when input is a regular file") func from_file_body() async throws {
    let infil = try tmpfile("empty", [UInt8]())
    let outfil = "output"
    defer {
      rm(infil)
    }
    let a = try await tryInput("script", [outfil], infil )
    #expect(a == 0)
    
  }
  
  
  @Test("Ignore tcgetattr() failure when input is a device", .disabled("not yet implemented")) func from_null() throws {
    fatalError("not yet implemented")
  }

  @Test("Ignore tcgetattr() failure when input is a pipe", .disabled("not yet implemented")) func from_pipe() throws {
    fatalError("not yet implemented")
  }
  
  
  // input is a file, a device, or a pipe
  public func tryInput(_ executable: String, _ args: [String], _ input : FilePath) async throws -> Int32 {
    let process = DarwinProcess()

    let pid = try await process.launch(executable, withStdin: input, args: args, env: ["SHELL" : "/bin/sh", "PS1" : "$"] )

/*
    var writeok = true
    
    Task.detached {
        if writeok {
  //        print("writing \(args)")
          input.fileHandleForWriting.write( input.data(using: .utf8) ?? Data() )
          try? input.fileHandleForWriting.close()
        }
      }
    }
     */
    
    Task.detached {
      try await Task.sleep(for: .seconds(1) )
  //    print("gonna interrupt")
      if 0 != kill(pid, SIGINT) {
        throw POSIXErrno(fn: "signaling SIGINT") }
    }
    
    let po = try await process.value()

    return po.code

  }

  
  
}
