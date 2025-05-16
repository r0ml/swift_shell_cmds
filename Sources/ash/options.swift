// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation
import CMigration

@MainActor public var optval = Array(repeating: CChar(0), count: optname.count)
public let optletter = "efIimnsxvVECabupTPh"
public let optname : [ String ] = [
  "errexit",
  "noglob",
  "ignoreeof",
  "interactive",
  "monitor",
  "noexec",
  "stdin",
  "xtrace",
  "verbose",
  "vi",
  "emacs",
  "noclobber",
  "allexport",
  "notify",
  "nounset",
  "privileged",
  "trapsasync",
  "physical",
  "trackall",
  "nolog",
  ]

@MainActor @_cdecl("minus_o") public func minus_o(_ name : String?, _ val : CChar) {
  //  int i;
  //  const unsigned char *on;
  //  size_t len;
  
  if let name {
    if let i = optname.firstIndex(of: name) {
      setoptionbyindex(i, val);
      return;
    }
    // FIXME: call error somehow --
    error_("Illegal option -o \(name)")
  } else {
    if val != 0 {
      // "Pretty" output.
      out1str("Current option settings\n")
      for i in zip(optname, optval) {
        print( "\(i.0.leftPad(16)) \(i.1 != 0 ? "on" : "off")")
      }
    } else {
      // Output suitable for re-input to shell.
      for i in zip(optname, optval).enumerated() {
        print( i.0.isMultiple(of: 6) ? "set" : "", i.1.1 != 0 ? "-" : "+", i.1.0, terminator: i.0 % 6 == 5 || i.0 == optname.count - 1 ? "\n" : "")
      }
    }
  }
}

/// the index of option "privileged"
let privx = 15
/// the index of option Vflag
let Vflagx = 9
let Eflagx = 10

@_cdecl("setoptionbyindex") @MainActor public func setoptionbyindex(_ idx : Int, _ val : CChar) {
  if idx == privx && val == 0 && optval[privx] != 0 { // turning off privileged
    if setgid(getgid()) == -1 {
      error_("setgid");
    }
    if setuid(getuid()) == -1 {
      error_("setuid");
    }
  }
  optval[idx] = val;
  if val != 0 {
    // #%$ hack for ksh semantics
    if idx == Vflagx {
      optval[Eflagx] = 0
    }
    else if idx == Eflagx {
      optval[Vflagx] = 0
    }
  }
}

extension String {
  func leftPad(_ n : Int) -> String {
    return String(repeating: " ", count: max(0,n-self.count) )+self
  }
}


@_cdecl("eflag") @MainActor public func eflag() -> CChar { optval[0] }
@_cdecl("fflag") @MainActor public func fflag() -> CChar { optval[1] }
@_cdecl("Iflag") @MainActor public func Iflag() -> CChar { optval[2] }
@_cdecl("iflag") @MainActor public func iflag() -> CChar { optval[3] }
@_cdecl("mflag") @MainActor public func mflag() -> CChar { optval[4] }
@_cdecl("nflag") @MainActor public func nflag() -> CChar { optval[5] }
@_cdecl("sflag") @MainActor public func sflag() -> CChar { optval[6] }
@_cdecl("xflag") @MainActor public func xflag() -> CChar { optval[7] }
@_cdecl("vflag") @MainActor public func vflag() -> CChar { optval[8] }
@_cdecl("Vflag") @MainActor public func Vflag() -> CChar { optval[9] }
@_cdecl("Eflag") @MainActor public func Eflag() -> CChar { optval[10] }
@_cdecl("Cflag") @MainActor public func Cflag() -> CChar { optval[11] }
@_cdecl("aflag") @MainActor public func aflag() -> CChar { optval[12] }
@_cdecl("bflag") @MainActor public func bflag() -> CChar { optval[13] }
@_cdecl("uflag") @MainActor public func uflag() -> CChar { optval[14] }
@_cdecl("privileged") @MainActor public func privileged() -> CChar { optval[15] }
@_cdecl("Tflag") @MainActor public func Tflag() -> CChar { optval[16]}
@_cdecl("Pflag") @MainActor public func Pflag() -> CChar { optval[17]}
@_cdecl("hflag") @MainActor public func hflag() -> CChar { optval[18]}
@_cdecl("nologflag") @MainActor public func nologflag() -> CChar { optval[19] }


@_cdecl("eflagSet") @MainActor public func eflagSet(_ n : CChar) { optval[0] = n }
@_cdecl("fflagSet") @MainActor public func fflagSet(_ n : CChar) { optval[1] = n }
@_cdecl("IflagSet") @MainActor public func IflagSet(_ n : CChar) { optval[2] = n }
@_cdecl("iflagSet") @MainActor public func iflagSet(_ n : CChar) { optval[3] = n }
@_cdecl("mflagSet") @MainActor public func mflagSet(_ n : CChar) { optval[4] = n }
@_cdecl("nflagSet") @MainActor public func nflagSet(_ n : CChar) { optval[5] = n }
@_cdecl("sflagSet") @MainActor public func sflagSet(_ n : CChar) { optval[6] = n }
@_cdecl("xflagSet") @MainActor public func xflagSet(_ n : CChar) { optval[7] = n }
@_cdecl("vflagSet") @MainActor public func vflagSet(_ n : CChar) { optval[8] = n }
@_cdecl("VflagSet") @MainActor public func VflagSet(_ n : CChar) { optval[9] = n }
@_cdecl("EflagSet") @MainActor public func EflagSet(_ n : CChar) { optval[10] = n }
@_cdecl("CflagSet") @MainActor public func CflagSet(_ n : CChar) { optval[11] = n }
@_cdecl("aflagSet") @MainActor public func aflagSet(_ n : CChar) { optval[12] = n }
@_cdecl("bflagSet") @MainActor public func bflagSet(_ n : CChar) { optval[13] = n }
@_cdecl("uflagSet") @MainActor public func uflagSet(_ n : CChar) { optval[14] = n }
@_cdecl("privilegedSet") @MainActor public func privilegedSet(_ n : CChar) { optval[15] = n }
@MainActor public func TflagSet(_ n : CChar) { optval[16] = n }
@MainActor public func PflagSet(_ n : CChar) { optval[17] = n }
@MainActor public func hflagSet(_ n : CChar) { optval[18] = n }
@MainActor public func nologflagSet(_ n : CChar) { optval[19] = n }

@_cdecl("getOptval") @MainActor public func getOptval(_ n : Int32) -> CChar { optval[Int(n)] }
@_cdecl("getOptletter") @MainActor public func getOptletter(_ n : Int32) -> CChar { CChar(Array(optletter)[Int(n)].asciiValue!) }
@_cdecl("setOptval") @MainActor public func setOptval(_ n : Int32, _ v : CChar) { optval[Int(n)] = v }

@_cdecl("sizeofOptval") @MainActor public func sizeofOptval() -> Int32 { Int32(MemoryLayout.size(ofValue: optval)) }
@_cdecl("addressOptval") @MainActor public func addressOptval() -> UnsafeRawPointer {
  return optval.withUnsafeBytes { $0.baseAddress! }
}
