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

@Suite("script") struct scriptTest {

  @Test("Ignore tcgetattr() failure when input is a regular file") func from_file_body() throws {
    let infil = "empty"
    let outfil = "output"
    FileManager.default.createFile(atPath: infil, contents: Data() )
    defer {
      try? FileManager.default.removeItem(atPath: infil)
    }
    let a = tryInput("script", [outfil], FileHandle(forReadingAtPath: infil)! )
    #expect(a == 0)
    
  }
  
  
  @Test("Ignore tcgetattr() failure when input is a device") func from_null() throws {
    fatalError("not yet implemented")
  }

  @Test("Ignore tcgetattr() failure when input is a pipe") func from_pipe() throws {
    fatalError("not yet implemented")
  }
  
  
  // input is a file, a device, or a pipe
  public func tryInput(_ executable: String, _ args: [String], _ input : FileHandle) -> Int32 {
    let process = Process()

    let output = Pipe()
    let stderr = Pipe()

    let d = Bundle(for: Clem.self).bundleURL
    let execu = d.deletingLastPathComponent().appending(component: executable).path(percentEncoded:false)
    
  //  print("launchPath \(execu)")
    
    process.launchPath = execu
    process.arguments = args
    process.standardOutput = output
    process.standardInput = input
    process.standardError = stderr
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
    
    let k1 = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    let k2 = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    return process.terminationStatus // , k1, k2)

  }

  
  
}
