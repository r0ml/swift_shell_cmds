// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation
import CMigration

@main class sh {
  static func main() {
    mainx(CommandLine.argc, CommandLine.unsafeArgv)
  }
}

func TRACE(_ param : String) {
  let DEBUG = true
  if DEBUG {
    print(param)
  }
}

/**
 * Read and execute commands.  "Top" is nonzero for the top level command
 * loop; it turns on prompting if the shell is interactive.
 */

/*
@MainActor func cmdloop(_ top : Int) {
  var smark : stackmark
  var inter : Int
  var numeof : Int = 0

//  union node *n;

  TRACE("cmdloop(\(top)) called")
  setstackmark(&smark);
  while true {
    if pendingsig != 0 {
      dotrap()
    }
    inter = 0;
    if iflag && top {
      inter += 1
      showjobs(1, SHOWJOBS_DEFAULT);
      chkmail(0);
      flushout(&output);
    }
    n = parsecmd(inter);
    /* showtree(n); DEBUG */
    if (n == NEOF) {
      if (!top || numeof >= 50)
        break;
      if (!stoppedjobs()) {
        if (!Iflag)
          break;
        out2fmt_flush("\nUse \"exit\" to leave shell.\n");
      }
      numeof++;
    } else if (n != NULL && nflag == 0) {
      job_warning = (job_warning == 2) ? 1 : 0;
      numeof = 0;
      evaltree(n, 0);
    }
    popstackmark(&smark);
    setstackmark(&smark);
    if (evalskip != 0) {
      if (evalskip == SKIPRETURN)
        evalskip = 0;
      break;
    }
  }
  popstackmark(&smark);
}
*/


