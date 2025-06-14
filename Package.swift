// swift-tools-version: 6.0

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

import PackageDescription
import Foundation

let package = Package(
  name: "shell_cmds",
  platforms: [.macOS(.v15), .iOS(.v15)],
  dependencies: [
     .package(url: "https://github.com/r0ml/ShellTesting.git" , branch: "main"),
//     .package(path: "../ShellTesting"),
      .package(url: "https://github.com/r0ml/CMigration.git", branch: "main"),
// .package(name: "CMigration", path: "../CMigration"),
     .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main"),
  ],

  targets:
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    generateTargets()
    + generateTestTargets()
)

func generateTargets() -> [Target] {
    var res = [Target]()
    let cd = try! FileManager.default.contentsOfDirectory(atPath: "Sources")
    print(cd)
    for i in cd {
      let t = Target.executableTarget(name: i, dependencies: [.product(name: "CMigration", package: "CMigration")] )
        res.append(t)
    }
    return res
}
 

func generateTestTargets() -> [Target] {
    var res = [Target]()
    
    let cd = try! FileManager.default.contentsOfDirectory(atPath: "Tests")
    print(cd)
    for i in cd {
      if i == ".DS_Store" { continue }
        let r = try! FileManager.default.fileExists(atPath: "Tests/\(i)/Resources")
      let x = try! FileManager.default.contentsOfDirectory(atPath: "Tests/\(i)").filter { $0.hasSuffix(".xctestplan") }
        let rr = r ? [Resource.copy("Resources")] : []
        let t = Target.testTarget(name: i,
                                  dependencies: [.product(name: "ShellTesting", package: "ShellTesting"),
                                                 .product(name: "Subprocess", package: "swift-subprocess"),
                                                 .target(name: i.replacingOccurrences(of: "Test", with: ""))],
                                  path: nil,
                                  exclude: x
                                  , resources: rr
        )
        res.append(t)
    }
    return res
}
