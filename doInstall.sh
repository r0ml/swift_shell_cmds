#!/bin/sh
set -e -x

if [ $# -eq 0 ]; then
    echo "Error: Root directory not provided"
    exit 1  # Exit with a non-zero status code to indicate an error
fi

XDSTROOT=$1
echo XDSTROOT: $XDSTROOT

BINDIR="$XDSTROOT/bin"
LIBEXECDIR="$XDSTROOT/libexec"
MANDIR="$XDSTROOT/share/man"

swift build --configuration release

install -m 0755 -d "$BINDIR/bin"
install -m 0755 -d "$MANDIR/man1"
install -m 0755 -d "$MANDIR/man8"
install -m 0644 Manuals/*.1 "$MANDIR/man1"
install -m 0644 Manuals/*.8 "$MANDIR/man8"
ln -f "$MANDIR/man1/test.1" "$MANDIR/man1/[.1"

BINS=`'ls' Sources | grep -v -e path_helper`
EXECS=path_helper
cd .build/release

install -m 0755 $BINS "$BINDIR"
install -m 0755 $EXECS "$LIBEXECDIR"

ln -f "$BINDIR/test" "["
