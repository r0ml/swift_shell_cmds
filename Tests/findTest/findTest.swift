
// Generated by Robert M. Lefkowitz <r0ml@liberally.net> in 2024
// from a file containing the following notice:

/*
  Copyright 2017, Conrad Meyer <cem@FreeBSD.org>.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:
 
  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  z OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import ShellTesting

@Suite("find tests") final class findTest : ShellTest {
  let cmd = "find"
  let suiteBundle = "shell_cmds_findTest"

  var myDir : URL
  
  deinit {
      try! FileManager.default.removeItem(at: myDir)
  }
  
  init() throws {
    // mkdir test
    myDir = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString )
    try FileManager.default.createDirectory(at: myDir, withIntermediateDirectories: false)
  }
  
  @Test func find_newer_link() async throws {
    
    // ln -s file1 test/link
    let ll = myDir.appending(component: "link")
    try FileManager.default.createSymbolicLink(atPath: ll.relativePath, withDestinationPath: "file1")
    
    var isoDate : String
    var date : Date
    let dateFormatter = ISO8601DateFormatter()

    // touch -d 2017-12-31T10:00:00Z -h test/link
    isoDate = "2023-12-31T06:00:00Z"

    /// Bah! This doesn't work because Foundation has no equivalent to AT_SYMLINK_NOFOLLOW for symbolic links
/*
    date = dateFormatter.date(from:isoDate)!
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: ll.relativePath)
*/

    var t4 = tm()
    let _ = strptime(isoDate, "%Y-%m-%dT%H:%M:%S%Z", &t4) // this should return nil
    let t3 = Int(timegm(&t4))
    var t1 = timespec()
    t1.tv_sec = t3
    t1.tv_nsec = 0
    let times : [timespec] = [t1, t1]
    
    let stat = utimensat(-1, ll.relativePath, times, AT_SYMLINK_NOFOLLOW)
    #expect(stat == 0)
    
    // touch -d 2017-12-31T11:00:00Z test/file2
    isoDate = "2023-12-31T09:00:00Z"
    date = dateFormatter.date(from:isoDate)!

    FileManager.default.createFile(atPath: myDir.appending(component: "file2").path(percentEncoded: false), contents: nil, attributes: [.modificationDate: date])
    

    // touch -d 2017-12-31T12:00:00Z test/file1
    isoDate = "2023-12-31T12:00:00Z"
    date = dateFormatter.date(from:isoDate)!

    FileManager.default.createFile(atPath: myDir.appending(component: "file1").path(percentEncoded: false), contents: nil, attributes: [.modificationDate: date])


//    let j = try captureStdoutLaunch(Self.self, "find", [myDir.relativePath, "-newer", myDir.appending(component: "link").relativePath])
    let res = """
\(myDir.relativePath)
\(myDir.appending(component: "file2").relativePath)
\(myDir.appending(component: "file1").relativePath)

"""
    try await run(output: res, args: myDir, "-newer", myDir.appending(component: "link") )
//    #expect(j.1 == res)
  }
  
  @Test(.disabled("original test code implies a different result than the find shipped with macOS")) func find_samefile_link() async throws {
    let s = myDir.appending(component: "test")

    try FileManager.default.createDirectory(at: s, withIntermediateDirectories: false)
    try FileManager.default.createSymbolicLink(atPath: s.appending(component: "link2").relativePath, withDestinationPath: "file3")
    FileManager.default.createFile(atPath: s.appending(component: "file3").path(percentEncoded: false), contents: nil)

//    let j = try captureStdoutLaunch(Self.self, "find", [s.relativePath, "-samefile", s.appending(component: "link2").relativePath])
    // FIXME: the find shipped with macOS produces "file3" here, NOT link2
//    #expect(j.1 == (s.appending(component: "link2").relativePath + "\n") )
    try await run(output: s.appending(component: "link2").relativePath + "\n", args: s, "-samefile", s.appending(component: "link2")  )
  }
  
  @Test
  func newerBm_msprec() async throws {
    let s = myDir.appending(component: "scratch")

    try FileManager.default.createDirectory(at: s, withIntermediateDirectories: false)
    FileManager.default.createFile(atPath: myDir.appending(component: "baseline").path(percentEncoded: false), contents: nil)
    FileManager.default.createFile(atPath: s.appending(component: "file_a").path(percentEncoded: false), contents: nil)
    try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
    FileManager.default.createFile(atPath: s.appending(component: "file_b").path(percentEncoded: false), contents: nil)

//    let j = try captureStdoutLaunch(Self.self, "find", [s.relativePath, "-type", "f", "-newerBm", myDir.appending(component: "baseline").relativePath])

    let res = """
\(s.appending(component: "file_a").relativePath)
\(s.appending(component: "file_b").relativePath)

"""
    try await run(output: res, args: s, "-type", "f", "-newerBm", myDir.appending(component: "baseline") )
  }

}
