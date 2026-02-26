
1 - mktempTest creates directories in the project directory.  This should be modernized to the /tmp support in `ShellTest`

2 - the command `xcodebuild -scheme xxx -configuration Release install DSTROOT=/opt/local`  will install target command xxx into /opt/local/bin

3 - need a test for   id nobody   

======

deprecate the old ProcessRunner

for getting rid of Darwin references:

kill (and the SIG definitions)
signal
getpriority and getpgid
ctime and gettimeofday
iovec
strftime and localtime
utmpx, winsize, ttyname, ioctl
setutxent, endutxent, getutxent
faccessat
unlink
getcwd
mkdtemp, mkstemp
flock
srandom, arc4random
getgrouplist  and   getgroups
gethostname   and   sethostname
user_from_uid  and  group_from_gid

look at  hexdump/display.swift
