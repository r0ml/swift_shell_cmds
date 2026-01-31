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
    let a = tryInput("script", [outfil], infil )
    #expect(a == 0)
    
  }
  
  
  @Test("Ignore tcgetattr() failure when input is a device", .disabled("not yet implemented")) func from_null() throws {
    fatalError("not yet implemented")
  }

  @Test("Ignore tcgetattr() failure when input is a pipe", .disabled("not yet implemented")) func from_pipe() throws {
    fatalError("not yet implemented")
  }
  
  
  // input is a file, a device, or a pipe
  public func tryInput(_ executable: String, _ args: [String], _ input : FilePath) -> Int32 {
    let process = Process()

    let output = Pipe()
    let stderr = Pipe()

    let d = Bundle(for: ShellProcess.self).bundleURL
    let execu = d.deletingLastPathComponent().appending(component: executable).path(percentEncoded:false)
    
  //  print("launchPath \(execu)")
    
    process.launchPath = execu
    process.arguments = args


    process.standardOutput = output.fileHandleForWriting
    process.standardInput = input
    process.standardError = stderr.fileHandleForWriting

    process.environment = ["SHELL" : "/bin/sh", "PS1" : "$ "]

    process.launch()

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
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 1)
  //    print("gonna interrupt")
      process.interrupt()
    }
    
    process.waitUntilExit()
//    writeok = false
  //  print("finished waiting \(args)")
    output.fileHandleForWriting.closeFile()
    stderr.fileHandleForWriting.closeFile()
    
    let k1 = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    let k2 = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    return process.terminationStatus // , k1, k2)

  }

  
  
}
