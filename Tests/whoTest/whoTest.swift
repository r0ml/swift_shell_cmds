// Written by Robert M. Lefkowitz <r0ml@liberal.software> in 2026

import ShellTesting
import Darwin

/// Records for the login databases made for the tests: the type, user, line, process, host, time and identifier.
let whoRecordSets: [String: [(Int16, String, String, Int32, String, Int, String)]] = [
  "one": [(7, "alice", "console", 123, "", 1700000000, "a001")],
  "hosts": [(7, "bob", "null", 9999, "remote.example.com", 1700001000, "b001"), (7, "carol", "tty", 0, "", 1700002000, "b002"), (7, "dave", "nosuchtty", 5, "h", 1700003000, "b003")],
  "mixed": [(2, "", "", 0, "", 1700000000, "m001"), (7, "alice", "console", 123, "", 1700000100, "m002"), (8, "", "ttys002", 44, "", 1700000200, "m003"), (6, "", "ttys003", 45, "", 1700000300, "m004"), (5, "", "ttys004", 1, "", 1700000400, "m005"), (7, "", "null", 9, "", 1700000500, "m006"), (7, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "tty", 12345678, "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy", 1700000600, "m007"), (1, "", "", 0, "", 1700000700, "m008"), (3, "", "", 0, "", 1700000800, "m009"), (4, "", "", 0, "", 1700000900, "m010"), (9, "acct", "null", 3, "", 1700001000, "m011")],
  "many": [(7, "user00", "console", 100, "", 1700000000, "u000"), (7, "user01", "console", 101, "", 1700000060, "u001"), (7, "user02", "console", 102, "", 1700000120, "u002"), (7, "user03", "console", 103, "", 1700000180, "u003"), (7, "user04", "console", 104, "", 1700000240, "u004"), (7, "user05", "console", 105, "", 1700000300, "u005"), (7, "user06", "console", 106, "", 1700000360, "u006"), (7, "user07", "console", 107, "", 1700000420, "u007"), (7, "user08", "console", 108, "", 1700000480, "u008"), (7, "user09", "console", 109, "", 1700000540, "u009"), (7, "user10", "console", 110, "", 1700000600, "u010"), (7, "user11", "console", 111, "", 1700000660, "u011"), (7, "user12", "console", 112, "", 1700000720, "u012"), (7, "user13", "console", 113, "", 1700000780, "u013"), (7, "user14", "console", 114, "", 1700000840, "u014"), (7, "user15", "console", 115, "", 1700000900, "u015"), (7, "user16", "console", 116, "", 1700000960, "u016"), (7, "user17", "console", 117, "", 1700001020, "u017"), (7, "user18", "console", 118, "", 1700001080, "u018"), (7, "user19", "console", 119, "", 1700001140, "u019"), (7, "user20", "console", 120, "", 1700001200, "u020"), (7, "user21", "console", 121, "", 1700001260, "u021"), (7, "user22", "console", 122, "", 1700001320, "u022"), (7, "user23", "console", 123, "", 1700001380, "u023"), (7, "user24", "console", 124, "", 1700001440, "u024")],
  "empty": [],
  "absent": [(7, "u1", "nosuch1", 1, "", 1700000000, "d001"), (7, "u2", "nosuch2", 2, "", 1700000000, "d002")],
]

/// Results recorded from the system's who, for the databases made from `whoRecordSets`: the name of the database, the
/// arguments, the environment added (the zone is UTC and the language C otherwise), the exit status, the standard output
/// and the error output.
let whoRecordedResults: [(String, [String], [String: String], Int, String, String)] = [
    ("one", [], [:], 0, "alice            console      Nov 14 22:13 \n", ""),
    ("one", ["-a"], [:], 0, "alice            console      Nov 14 22:13 \n   .       run-level 3\n", ""),
    ("one", ["-b"], [:], 0, "", ""),
    ("one", ["-d"], [:], 0, "", ""),
    ("one", ["-l"], [:], 0, "", ""),
    ("one", ["-p"], [:], 0, "alice            console      Nov 14 22:13 \n", ""),
    ("one", ["-q"], [:], 0, "alice            \n# users = 1\n", ""),
    ("one", ["-r"], [:], 0, "   .       run-level 3\n", ""),
    ("one", ["-s"], [:], 0, "alice            console      Nov 14 22:13 \n", ""),
    ("one", ["-t"], [:], 0, "alice            console      Nov 14 22:13 \n", ""),
    ("one", ["-T"], [:], 0, "alice            + console      Nov 14 22:13 \n", ""),
    ("one", ["-u"], [:], 0, "alice            console      Nov 14 22:13  old       123 \n", ""),
    ("one", ["-H"], [:], 0, "NAME             LINE         TIME         FROM            \nalice            console      Nov 14 22:13 \n", ""),
    ("one", ["-Hu"], [:], 0, "NAME             LINE         TIME         IDLE       PID FROM            \nalice            console      Nov 14 22:13  old       123 \n", ""),
    ("one", ["-HT"], [:], 0, "NAME             S LINE         TIME         FROM            \nalice            + console      Nov 14 22:13 \n", ""),
    ("one", ["-HuT"], [:], 0, "NAME             S LINE         TIME         IDLE  FROM            \nalice            + console      Nov 14 22:13  old  \n", ""),
    ("one", ["-Hs"], [:], 0, "NAME             LINE         TIME         FROM            \nalice            console      Nov 14 22:13 \n", ""),
    ("one", ["-su"], [:], 0, "alice            console      Nov 14 22:13 \n", ""),
    ("one", ["-sT"], [:], 0, "alice            console      Nov 14 22:13 \n", ""),
    ("one", ["-bu"], [:], 0, "", ""),
    ("one", ["-bT"], [:], 0, "", ""),
    ("one", ["-dH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("one", ["-lH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("one", ["-rH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("one", ["-H", "-q"], [:], 0, "alice            \n# users = 1\n", ""),
    ("one", ["-a", "-H"], [:], 0, "NAME             LINE         TIME         FROM            \nalice            console      Nov 14 22:13 \n   .       run-level 3\n", ""),
    ("one", ["-aH"], [:], 0, "NAME             LINE         TIME         FROM            \nalice            console      Nov 14 22:13 \n   .       run-level 3\n", ""),
    ("one", ["-x"], [:], 1, "", "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("one", ["-z"], [:], 1, "", "who: illegal option -- z\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("one", ["a"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("one", ["am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("one", ["am", "x"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("one", ["i", "am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("hosts", [], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-a"], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \ndave             nosuchtty    Nov 14 23:03 (h)\n   .       run-level 3\n", ""),
    ("hosts", ["-b"], [:], 0, "", ""),
    ("hosts", ["-d"], [:], 0, "", ""),
    ("hosts", ["-l"], [:], 0, "", ""),
    ("hosts", ["-p"], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-q"], [:], 0, "bob              carol            dave             \n# users = 3\n", ""),
    ("hosts", ["-r"], [:], 0, "   .       run-level 3\n", ""),
    ("hosts", ["-s"], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-t"], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-T"], [:], 0, "bob              + null         Nov 14 22:30 (remote.example.com)\ncarol            + tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-u"], [:], 0, "bob              null         Nov 14 22:30   .       9999 (remote.example.com)\ncarol            tty          Nov 14 22:46  old         ? \n", ""),
    ("hosts", ["-H"], [:], 0, "NAME             LINE         TIME         FROM            \nbob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-Hu"], [:], 0, "NAME             LINE         TIME         IDLE       PID FROM            \nbob              null         Nov 14 22:30   .       9999 (remote.example.com)\ncarol            tty          Nov 14 22:46  old         ? \n", ""),
    ("hosts", ["-HT"], [:], 0, "NAME             S LINE         TIME         FROM            \nbob              + null         Nov 14 22:30 (remote.example.com)\ncarol            + tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-HuT"], [:], 0, "NAME             S LINE         TIME         IDLE  FROM            \nbob              + null         Nov 14 22:30   .   (remote.example.com)\ncarol            + tty          Nov 14 22:46  old  \n", ""),
    ("hosts", ["-Hs"], [:], 0, "NAME             LINE         TIME         FROM            \nbob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-su"], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-sT"], [:], 0, "bob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \n", ""),
    ("hosts", ["-bu"], [:], 0, "", ""),
    ("hosts", ["-bT"], [:], 0, "", ""),
    ("hosts", ["-dH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("hosts", ["-lH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("hosts", ["-rH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("hosts", ["-H", "-q"], [:], 0, "bob              carol            dave             \n# users = 3\n", ""),
    ("hosts", ["-a", "-H"], [:], 0, "NAME             LINE         TIME         FROM            \nbob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \ndave             nosuchtty    Nov 14 23:03 (h)\n   .       run-level 3\n", ""),
    ("hosts", ["-aH"], [:], 0, "NAME             LINE         TIME         FROM            \nbob              null         Nov 14 22:30 (remote.example.com)\ncarol            tty          Nov 14 22:46 \ndave             nosuchtty    Nov 14 23:03 (h)\n   .       run-level 3\n", ""),
    ("hosts", ["-x"], [:], 1, "", "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("hosts", ["-z"], [:], 1, "", "who: illegal option -- z\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("hosts", ["a"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("hosts", ["am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("hosts", ["am", "x"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("hosts", ["i", "am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("mixed", [], [:], 0, "alice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-a"], [:], 0, "                 system boot  Nov 14 22:13 \nalice            console      Nov 14 22:15 \n                              Nov 14 22:16 \tterm=0 exit=0\n                              Nov 14 22:20 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n                              Jan  1 00:00 \n                              Nov 14 22:26 \n                              Nov 14 22:28 \n   .       run-level 3\n", ""),
    ("mixed", ["-b"], [:], 0, "                 system boot  Nov 14 22:13 \n", ""),
    ("mixed", ["-d"], [:], 0, "                              Nov 14 22:16 \tterm=0 exit=0\n", ""),
    ("mixed", ["-l"], [:], 0, "", ""),
    ("mixed", ["-p"], [:], 0, "alice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-q"], [:], 0, "alice            xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n# users = 2\n", ""),
    ("mixed", ["-r"], [:], 0, "   .       run-level 3\n", ""),
    ("mixed", ["-s"], [:], 0, "alice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-t"], [:], 0, "alice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-T"], [:], 0, "alice            + console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx + tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-u"], [:], 0, "alice            console      Nov 14 22:15  old       123 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23  old  12345678 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-H"], [:], 0, "NAME             LINE         TIME         FROM            \nalice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-Hu"], [:], 0, "NAME             LINE         TIME         IDLE       PID FROM            \nalice            console      Nov 14 22:15  old       123 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23  old  12345678 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-HT"], [:], 0, "NAME             S LINE         TIME         FROM            \nalice            + console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx + tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-HuT"], [:], 0, "NAME             S LINE         TIME         IDLE  FROM            \nalice            + console      Nov 14 22:15  old  \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx + tty          Nov 14 22:23  old  (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-Hs"], [:], 0, "NAME             LINE         TIME         FROM            \nalice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-su"], [:], 0, "alice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-sT"], [:], 0, "alice            console      Nov 14 22:15 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n", ""),
    ("mixed", ["-bu"], [:], 0, "                 system boot  Nov 14 22:13  old         ? \n", ""),
    ("mixed", ["-bT"], [:], 0, "                 - system boot  Nov 14 22:13 \n", ""),
    ("mixed", ["-dH"], [:], 0, "NAME             LINE         TIME         FROM            \n                              Nov 14 22:16 \tterm=0 exit=0\n", ""),
    ("mixed", ["-lH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("mixed", ["-rH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("mixed", ["-H", "-q"], [:], 0, "alice            xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n# users = 2\n", ""),
    ("mixed", ["-a", "-H"], [:], 0, "NAME             LINE         TIME         FROM            \n                 system boot  Nov 14 22:13 \nalice            console      Nov 14 22:15 \n                              Nov 14 22:16 \tterm=0 exit=0\n                              Nov 14 22:20 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n                              Jan  1 00:00 \n                              Nov 14 22:26 \n                              Nov 14 22:28 \n   .       run-level 3\n", ""),
    ("mixed", ["-aH"], [:], 0, "NAME             LINE         TIME         FROM            \n                 system boot  Nov 14 22:13 \nalice            console      Nov 14 22:15 \n                              Nov 14 22:16 \tterm=0 exit=0\n                              Nov 14 22:20 \nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx tty          Nov 14 22:23 (yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy)\n                              Jan  1 00:00 \n                              Nov 14 22:26 \n                              Nov 14 22:28 \n   .       run-level 3\n", ""),
    ("mixed", ["-x"], [:], 1, "", "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("mixed", ["-z"], [:], 1, "", "who: illegal option -- z\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("mixed", ["a"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("mixed", ["am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("mixed", ["am", "x"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("mixed", ["i", "am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", [], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-a"], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n   .       run-level 3\n", ""),
    ("many", ["-b"], [:], 0, "", ""),
    ("many", ["-d"], [:], 0, "", ""),
    ("many", ["-l"], [:], 0, "", ""),
    ("many", ["-p"], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-q"], [:], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", ""),
    ("many", ["-r"], [:], 0, "   .       run-level 3\n", ""),
    ("many", ["-s"], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-t"], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-T"], [:], 0, "user00           + console      Nov 14 22:13 \nuser01           + console      Nov 14 22:14 \nuser02           + console      Nov 14 22:15 \nuser03           + console      Nov 14 22:16 \nuser04           + console      Nov 14 22:17 \nuser05           + console      Nov 14 22:18 \nuser06           + console      Nov 14 22:19 \nuser07           + console      Nov 14 22:20 \nuser08           + console      Nov 14 22:21 \nuser09           + console      Nov 14 22:22 \nuser10           + console      Nov 14 22:23 \nuser11           + console      Nov 14 22:24 \nuser12           + console      Nov 14 22:25 \nuser13           + console      Nov 14 22:26 \nuser14           + console      Nov 14 22:27 \nuser15           + console      Nov 14 22:28 \nuser16           + console      Nov 14 22:29 \nuser17           + console      Nov 14 22:30 \nuser18           + console      Nov 14 22:31 \nuser19           + console      Nov 14 22:32 \nuser20           + console      Nov 14 22:33 \nuser21           + console      Nov 14 22:34 \nuser22           + console      Nov 14 22:35 \nuser23           + console      Nov 14 22:36 \nuser24           + console      Nov 14 22:37 \n", ""),
    ("many", ["-u"], [:], 0, "user00           console      Nov 14 22:13  old       100 \nuser01           console      Nov 14 22:14  old       101 \nuser02           console      Nov 14 22:15  old       102 \nuser03           console      Nov 14 22:16  old       103 \nuser04           console      Nov 14 22:17  old       104 \nuser05           console      Nov 14 22:18  old       105 \nuser06           console      Nov 14 22:19  old       106 \nuser07           console      Nov 14 22:20  old       107 \nuser08           console      Nov 14 22:21  old       108 \nuser09           console      Nov 14 22:22  old       109 \nuser10           console      Nov 14 22:23  old       110 \nuser11           console      Nov 14 22:24  old       111 \nuser12           console      Nov 14 22:25  old       112 \nuser13           console      Nov 14 22:26  old       113 \nuser14           console      Nov 14 22:27  old       114 \nuser15           console      Nov 14 22:28  old       115 \nuser16           console      Nov 14 22:29  old       116 \nuser17           console      Nov 14 22:30  old       117 \nuser18           console      Nov 14 22:31  old       118 \nuser19           console      Nov 14 22:32  old       119 \nuser20           console      Nov 14 22:33  old       120 \nuser21           console      Nov 14 22:34  old       121 \nuser22           console      Nov 14 22:35  old       122 \nuser23           console      Nov 14 22:36  old       123 \nuser24           console      Nov 14 22:37  old       124 \n", ""),
    ("many", ["-H"], [:], 0, "NAME             LINE         TIME         FROM            \nuser00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-Hu"], [:], 0, "NAME             LINE         TIME         IDLE       PID FROM            \nuser00           console      Nov 14 22:13  old       100 \nuser01           console      Nov 14 22:14  old       101 \nuser02           console      Nov 14 22:15  old       102 \nuser03           console      Nov 14 22:16  old       103 \nuser04           console      Nov 14 22:17  old       104 \nuser05           console      Nov 14 22:18  old       105 \nuser06           console      Nov 14 22:19  old       106 \nuser07           console      Nov 14 22:20  old       107 \nuser08           console      Nov 14 22:21  old       108 \nuser09           console      Nov 14 22:22  old       109 \nuser10           console      Nov 14 22:23  old       110 \nuser11           console      Nov 14 22:24  old       111 \nuser12           console      Nov 14 22:25  old       112 \nuser13           console      Nov 14 22:26  old       113 \nuser14           console      Nov 14 22:27  old       114 \nuser15           console      Nov 14 22:28  old       115 \nuser16           console      Nov 14 22:29  old       116 \nuser17           console      Nov 14 22:30  old       117 \nuser18           console      Nov 14 22:31  old       118 \nuser19           console      Nov 14 22:32  old       119 \nuser20           console      Nov 14 22:33  old       120 \nuser21           console      Nov 14 22:34  old       121 \nuser22           console      Nov 14 22:35  old       122 \nuser23           console      Nov 14 22:36  old       123 \nuser24           console      Nov 14 22:37  old       124 \n", ""),
    ("many", ["-HT"], [:], 0, "NAME             S LINE         TIME         FROM            \nuser00           + console      Nov 14 22:13 \nuser01           + console      Nov 14 22:14 \nuser02           + console      Nov 14 22:15 \nuser03           + console      Nov 14 22:16 \nuser04           + console      Nov 14 22:17 \nuser05           + console      Nov 14 22:18 \nuser06           + console      Nov 14 22:19 \nuser07           + console      Nov 14 22:20 \nuser08           + console      Nov 14 22:21 \nuser09           + console      Nov 14 22:22 \nuser10           + console      Nov 14 22:23 \nuser11           + console      Nov 14 22:24 \nuser12           + console      Nov 14 22:25 \nuser13           + console      Nov 14 22:26 \nuser14           + console      Nov 14 22:27 \nuser15           + console      Nov 14 22:28 \nuser16           + console      Nov 14 22:29 \nuser17           + console      Nov 14 22:30 \nuser18           + console      Nov 14 22:31 \nuser19           + console      Nov 14 22:32 \nuser20           + console      Nov 14 22:33 \nuser21           + console      Nov 14 22:34 \nuser22           + console      Nov 14 22:35 \nuser23           + console      Nov 14 22:36 \nuser24           + console      Nov 14 22:37 \n", ""),
    ("many", ["-HuT"], [:], 0, "NAME             S LINE         TIME         IDLE  FROM            \nuser00           + console      Nov 14 22:13  old  \nuser01           + console      Nov 14 22:14  old  \nuser02           + console      Nov 14 22:15  old  \nuser03           + console      Nov 14 22:16  old  \nuser04           + console      Nov 14 22:17  old  \nuser05           + console      Nov 14 22:18  old  \nuser06           + console      Nov 14 22:19  old  \nuser07           + console      Nov 14 22:20  old  \nuser08           + console      Nov 14 22:21  old  \nuser09           + console      Nov 14 22:22  old  \nuser10           + console      Nov 14 22:23  old  \nuser11           + console      Nov 14 22:24  old  \nuser12           + console      Nov 14 22:25  old  \nuser13           + console      Nov 14 22:26  old  \nuser14           + console      Nov 14 22:27  old  \nuser15           + console      Nov 14 22:28  old  \nuser16           + console      Nov 14 22:29  old  \nuser17           + console      Nov 14 22:30  old  \nuser18           + console      Nov 14 22:31  old  \nuser19           + console      Nov 14 22:32  old  \nuser20           + console      Nov 14 22:33  old  \nuser21           + console      Nov 14 22:34  old  \nuser22           + console      Nov 14 22:35  old  \nuser23           + console      Nov 14 22:36  old  \nuser24           + console      Nov 14 22:37  old  \n", ""),
    ("many", ["-Hs"], [:], 0, "NAME             LINE         TIME         FROM            \nuser00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-su"], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-sT"], [:], 0, "user00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n", ""),
    ("many", ["-bu"], [:], 0, "", ""),
    ("many", ["-bT"], [:], 0, "", ""),
    ("many", ["-dH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("many", ["-lH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("many", ["-rH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("many", ["-H", "-q"], [:], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", ""),
    ("many", ["-a", "-H"], [:], 0, "NAME             LINE         TIME         FROM            \nuser00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n   .       run-level 3\n", ""),
    ("many", ["-aH"], [:], 0, "NAME             LINE         TIME         FROM            \nuser00           console      Nov 14 22:13 \nuser01           console      Nov 14 22:14 \nuser02           console      Nov 14 22:15 \nuser03           console      Nov 14 22:16 \nuser04           console      Nov 14 22:17 \nuser05           console      Nov 14 22:18 \nuser06           console      Nov 14 22:19 \nuser07           console      Nov 14 22:20 \nuser08           console      Nov 14 22:21 \nuser09           console      Nov 14 22:22 \nuser10           console      Nov 14 22:23 \nuser11           console      Nov 14 22:24 \nuser12           console      Nov 14 22:25 \nuser13           console      Nov 14 22:26 \nuser14           console      Nov 14 22:27 \nuser15           console      Nov 14 22:28 \nuser16           console      Nov 14 22:29 \nuser17           console      Nov 14 22:30 \nuser18           console      Nov 14 22:31 \nuser19           console      Nov 14 22:32 \nuser20           console      Nov 14 22:33 \nuser21           console      Nov 14 22:34 \nuser22           console      Nov 14 22:35 \nuser23           console      Nov 14 22:36 \nuser24           console      Nov 14 22:37 \n   .       run-level 3\n", ""),
    ("many", ["-x"], [:], 1, "", "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", ["-z"], [:], 1, "", "who: illegal option -- z\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", ["a"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", ["am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", ["am", "x"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", ["i", "am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("empty", [], [:], 0, "", ""),
    ("empty", ["-a"], [:], 0, "   .       run-level 3\n", ""),
    ("empty", ["-b"], [:], 0, "", ""),
    ("empty", ["-d"], [:], 0, "", ""),
    ("empty", ["-l"], [:], 0, "", ""),
    ("empty", ["-p"], [:], 0, "", ""),
    ("empty", ["-q"], [:], 0, "# users = 0\n", ""),
    ("empty", ["-r"], [:], 0, "   .       run-level 3\n", ""),
    ("empty", ["-s"], [:], 0, "", ""),
    ("empty", ["-t"], [:], 0, "", ""),
    ("empty", ["-T"], [:], 0, "", ""),
    ("empty", ["-u"], [:], 0, "", ""),
    ("empty", ["-H"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("empty", ["-Hu"], [:], 0, "NAME             LINE         TIME         IDLE       PID FROM            \n", ""),
    ("empty", ["-HT"], [:], 0, "NAME             S LINE         TIME         FROM            \n", ""),
    ("empty", ["-HuT"], [:], 0, "NAME             S LINE         TIME         IDLE  FROM            \n", ""),
    ("empty", ["-Hs"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("empty", ["-su"], [:], 0, "", ""),
    ("empty", ["-sT"], [:], 0, "", ""),
    ("empty", ["-bu"], [:], 0, "", ""),
    ("empty", ["-bT"], [:], 0, "", ""),
    ("empty", ["-dH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("empty", ["-lH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("empty", ["-rH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("empty", ["-H", "-q"], [:], 0, "# users = 0\n", ""),
    ("empty", ["-a", "-H"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("empty", ["-aH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("empty", ["-x"], [:], 1, "", "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("empty", ["-z"], [:], 1, "", "who: illegal option -- z\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("empty", ["a"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("empty", ["am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("empty", ["am", "x"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("empty", ["i", "am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("absent", [], [:], 0, "", ""),
    ("absent", ["-a"], [:], 0, "u1               nosuch1      Nov 14 22:13 \nu2               nosuch2      Nov 14 22:13 \n   .       run-level 3\n", ""),
    ("absent", ["-b"], [:], 0, "", ""),
    ("absent", ["-d"], [:], 0, "", ""),
    ("absent", ["-l"], [:], 0, "", ""),
    ("absent", ["-p"], [:], 0, "", ""),
    ("absent", ["-q"], [:], 0, "u1               u2               \n# users = 2\n", ""),
    ("absent", ["-r"], [:], 0, "   .       run-level 3\n", ""),
    ("absent", ["-s"], [:], 0, "", ""),
    ("absent", ["-t"], [:], 0, "", ""),
    ("absent", ["-T"], [:], 0, "", ""),
    ("absent", ["-u"], [:], 0, "", ""),
    ("absent", ["-H"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("absent", ["-Hu"], [:], 0, "NAME             LINE         TIME         IDLE       PID FROM            \n", ""),
    ("absent", ["-HT"], [:], 0, "NAME             S LINE         TIME         FROM            \n", ""),
    ("absent", ["-HuT"], [:], 0, "NAME             S LINE         TIME         IDLE  FROM            \n", ""),
    ("absent", ["-Hs"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("absent", ["-su"], [:], 0, "", ""),
    ("absent", ["-sT"], [:], 0, "", ""),
    ("absent", ["-bu"], [:], 0, "", ""),
    ("absent", ["-bT"], [:], 0, "", ""),
    ("absent", ["-dH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("absent", ["-lH"], [:], 0, "NAME             LINE         TIME         FROM            \n", ""),
    ("absent", ["-rH"], [:], 0, "NAME             LINE         TIME         FROM            \n   .       run-level 3\n", ""),
    ("absent", ["-H", "-q"], [:], 0, "u1               u2               \n# users = 2\n", ""),
    ("absent", ["-a", "-H"], [:], 0, "NAME             LINE         TIME         FROM            \nu1               nosuch1      Nov 14 22:13 \nu2               nosuch2      Nov 14 22:13 \n   .       run-level 3\n", ""),
    ("absent", ["-aH"], [:], 0, "NAME             LINE         TIME         FROM            \nu1               nosuch1      Nov 14 22:13 \nu2               nosuch2      Nov 14 22:13 \n   .       run-level 3\n", ""),
    ("absent", ["-x"], [:], 1, "", "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("absent", ["-z"], [:], 1, "", "who: illegal option -- z\nusage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("absent", ["a"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("absent", ["am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("absent", ["am", "x"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("absent", ["i", "am"], [:], 1, "", "usage: who [-abdHlmpqrstTu] [am I] [file]\n"),
    ("many", ["-q"], ["COLUMNS": "40"], 0, "user00           user01          \nuser02           user03          \nuser04           user05          \nuser06           user07          \nuser08           user09          \nuser10           user11          \nuser12           user13          \nuser14           user15          \nuser16           user17          \nuser18           user19          \nuser20           user21          \nuser22           user23          \nuser24           \n# users = 25\n", ""),
    ("one", ["-q"], ["COLUMNS": "40"], 0, "alice            \n# users = 1\n", ""),
    ("empty", ["-q"], ["COLUMNS": "40"], 0, "# users = 0\n", ""),
    ("many", ["-q"], ["COLUMNS": "17"], 0, "user00          \nuser01          \nuser02          \nuser03          \nuser04          \nuser05          \nuser06          \nuser07          \nuser08          \nuser09          \nuser10          \nuser11          \nuser12          \nuser13          \nuser14          \nuser15          \nuser16          \nuser17          \nuser18          \nuser19          \nuser20          \nuser21          \nuser22          \nuser23          \nuser24          \n# users = 25\n", ""),
    ("one", ["-q"], ["COLUMNS": "17"], 0, "alice           \n# users = 1\n", ""),
    ("empty", ["-q"], ["COLUMNS": "17"], 0, "# users = 0\n", ""),
    ("many", ["-q"], ["COLUMNS": "16"], 0, "user00          \nuser01          \nuser02          \nuser03          \nuser04          \nuser05          \nuser06          \nuser07          \nuser08          \nuser09          \nuser10          \nuser11          \nuser12          \nuser13          \nuser14          \nuser15          \nuser16          \nuser17          \nuser18          \nuser19          \nuser20          \nuser21          \nuser22          \nuser23          \nuser24          \n# users = 25\n", ""),
    ("one", ["-q"], ["COLUMNS": "16"], 0, "alice           \n# users = 1\n", ""),
    ("empty", ["-q"], ["COLUMNS": "16"], 0, "# users = 0\n", ""),
    ("many", ["-q"], ["COLUMNS": "0"], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("one", ["-q"], ["COLUMNS": "0"], 0, "alice            \n# users = 1\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("empty", ["-q"], ["COLUMNS": "0"], 0, "# users = 0\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("many", ["-q"], ["COLUMNS": "-5"], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("one", ["-q"], ["COLUMNS": "-5"], 0, "alice            \n# users = 1\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("empty", ["-q"], ["COLUMNS": "-5"], 0, "# users = 0\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("many", ["-q"], ["COLUMNS": "abc"], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("one", ["-q"], ["COLUMNS": "abc"], 0, "alice            \n# users = 1\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("empty", ["-q"], ["COLUMNS": "abc"], 0, "# users = 0\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("many", ["-q"], ["COLUMNS": "12x"], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("one", ["-q"], ["COLUMNS": "12x"], 0, "alice            \n# users = 1\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("empty", ["-q"], ["COLUMNS": "12x"], 0, "# users = 0\n", "who: invalid COLUMNS environment variable ignored\n"),
    ("many", ["-q"], ["COLUMNS": ""], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", ""),
    ("one", ["-q"], ["COLUMNS": ""], 0, "alice            \n# users = 1\n", ""),
    ("empty", ["-q"], ["COLUMNS": ""], 0, "# users = 0\n", ""),
    ("many", ["-q"], ["COLUMNS": "200"], 0, "user00           user01           user02           user03           user04           user05           user06           user07           user08           user09           user10          \nuser11           user12           user13           user14           user15           user16           user17           user18           user19           user20           user21          \nuser22           user23           user24           \n# users = 25\n", ""),
    ("one", ["-q"], ["COLUMNS": "200"], 0, "alice            \n# users = 1\n", ""),
    ("empty", ["-q"], ["COLUMNS": "200"], 0, "# users = 0\n", ""),
    ("many", ["-q"], ["COLUMNS": "68"], 0, "user00           user01           user02           user03          \nuser04           user05           user06           user07          \nuser08           user09           user10           user11          \nuser12           user13           user14           user15          \nuser16           user17           user18           user19          \nuser20           user21           user22           user23          \nuser24           \n# users = 25\n", ""),
    ("one", ["-q"], ["COLUMNS": "68"], 0, "alice            \n# users = 1\n", ""),
    ("empty", ["-q"], ["COLUMNS": "68"], 0, "# users = 0\n", ""),
]

/// Login databases made in a directory of their own.
final class WhoDatabases {
  let root: String

  init() {
    var template = Array("/tmp/whotestXXXXXX".utf8CString)
    root = template.withUnsafeMutableBufferPointer { String(cString: mkdtemp($0.baseAddress!)) }
    for (name, records) in whoRecordSets {
      utmpxname(root + "/" + name)
      for record in records {
        var u = utmpx()
        u.ut_type = record.0
        func copy<T>(_ text: String, into field: inout T) {
          withUnsafeMutableBytes(of: &field) { b in
            for (i, byte) in text.utf8.prefix(b.count - 1).enumerated() { b[i] = byte }
          }
        }
        copy(record.1, into: &u.ut_user)
        copy(record.2, into: &u.ut_line)
        u.ut_pid = record.3
        copy(record.4, into: &u.ut_host)
        u.ut_tv.tv_sec = record.5
        withUnsafeMutableBytes(of: &u.ut_id) { b in
          for (i, byte) in record.6.utf8.prefix(b.count).enumerated() { b[i] = byte }
        }
        pututxline(&u)
      }
      endutxent()
    }
  }

  func remove() {
    for name in whoRecordSets.keys {
      unlink(root + "/" + name)
    }
    rmdir(root)
  }
}

@Suite("who", .serialized) final class whoTest : ShellTest {
  let cmd = "who"
  let suiteBundle = "shell_cmds_whoTest"

  @Test(arguments: whoRecordedResults)
  func matchesTheSystem(_ recorded: (String, [String], [String: String], Int, String, String)) async throws {
    let (name, flags, added, status, output, error) = recorded
    let databases = WhoDatabases()
    defer { databases.remove() }
    var environment = ["TZ": "UTC", "LC_ALL": "C"]
    environment.merge(added) { $1 }
    try await run(withStdin: "", status: status, output: output, error: error, args: flags + [databases.root + "/" + name], env: environment)
  }

  @Test func usage() async throws {
    try await run(withStdin: "", status: 1, output: "", error: "who: illegal option -- x\nusage: who [-abdHlmpqrstTu] [am I] [file]\n", args: "-x")
  }

  /// The "am i" form is the same as -m; and the two together are the name of a file too (the last of which is used).
  @Test func amI() async throws {
    let databases = WhoDatabases()
    defer { databases.remove() }
    let environment = ["TZ": "UTC", "LC_ALL": "C"]
    for form in [["am", "i"], ["am", "I"], ["-m"]] {
      try await run(withStdin: "", args: form + [databases.root + "/one"], env: environment) { po in
        // not on a terminal, and not in the database: the user running the tests, as they are
        #expect(po.code == 0)
        let text = String(decoding: po.data, as: UTF8.self)
        #expect(text.hasSuffix("\n") && text.dropLast().split(separator: "\n").count == 1, "\(text)")
      }
    }
  }

  /// Without a file, the real database of who is logged in is read: the same people as users says.
  @Test func theRealDatabase() async throws {
    try await run(withStdin: "", args: "-q") { po in
      let text = String(decoding: po.data, as: UTF8.self)
      #expect(text.contains("# users = "))
    }
  }

  /// A file that doesn't exist is a database with nobody in it.
  @Test func missingFile() async throws {
    try await run(withStdin: "", status: 0, output: "", error: "", args: "/nonexistent/utmpx-file")
  }
}
