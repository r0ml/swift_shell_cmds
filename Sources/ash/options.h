/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Kenneth Almquist.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)options.h	8.2 (Berkeley) 5/4/95
 * $FreeBSD: head/bin/sh/options.h 326025 2017-11-20 19:49:47Z pfg $
 */

struct shparam {
	int nparam;		/* # of positional parameters (without $0) */
	unsigned char malloc;	/* if parameter list dynamically allocated */
	unsigned char reset;	/* if getopts has been reset */
	char **p;		/* parameter list */
	char **optp;		/* parameter list for getopts */
	char **optnext;		/* next parameter to be processed by getopts */
	char *optptr;		/* used by getopts */
};

char eflag(void); //  optval[0]
char fflag(void); //  optval[1]
char Iflag(void); //  optval[2]
char iflag(void); //  optval[3]
char mflag(void); //  optval[4]
char nflag(void); //  optval[5]
char sflag(void); //  optval[6]
char xflag(void); //  optval[7]
char vflag(void); //  optval[8]
char Vflag(void); //  optval[9]
char	Eflag(void); //  optval[10]
char	Cflag(void); //  optval[11]
char	aflag(void); //  optval[12]
char	bflag(void); //  optval[13]
char	uflag(void); //  optval[14]
char	privileged(void); //  optval[15]
char	Tflag(void); //  optval[16]
char	Pflag(void); //  optval[17]
char	hflag(void); //  optval[18]
char	nologflag(void); // optval[19]

void eflagSet(char); //  optval[0]
void fflagSet(char); //  optval[1]
void IflagSet(char); //  optval[2]
void iflagSet(char); //  optval[3]
void mflagSet(char); //  optval[4]
void nflagSet(char); //  optval[5]
void sflagSet(char); //  optval[6]
void xflagSet(char); //  optval[7]
void vflagSet(char); //  optval[8]
void VflagSet(char); //  optval[9]
void EflagSet(char); //  optval[10]
void CflagSet(char); //  optval[11]
void aflagSet(char); //  optval[12]
void bflagSet(char); //  optval[13]
void uflagSet(char); //  optval[14]
void privilegedSet(char); //  optval[15]
void TflagSet(char); //  optval[16]
void PflagSet(char); //  optval[17]
void hflagSet(char); //  optval[18]
void nologflagSet(char); // optval[19]

char getOptval(int n);
char getOptletter(int n);
void setOptval(int n, char v);

int sizeofOptval(void);
char *addressOptval(void);

#define NSHORTOPTS	19
#define NOPTS		20

// extern char * optval;
// extern const char* optletter;

/*
 #ifdef DEFINE_OPTIONS
char optval[NOPTS];
const char optletter[NSHORTOPTS] = "efIimnsxvVECabupTPh";
static const unsigned char optname[] =
	"\007errexit"
	"\006noglob"
	"\011ignoreeof"
	"\013interactive"
	"\007monitor"
	"\006noexec"
	"\005stdin"
	"\006xtrace"
	"\007verbose"
	"\002vi"
	"\005emacs"
	"\011noclobber"
	"\011allexport"
	"\006notify"
	"\007nounset"
	"\012privileged"
	"\012trapsasync"
	"\010physical"
	"\010trackall"
	"\005nolog"
;
#endif
*/

extern char *minusc;		/* argument to -c option */
extern char *arg0;		/* $0 */
extern struct shparam shellparam;  /* $@ */
extern char **argptr;		/* argument list for builtin commands */
extern char *shoptarg;		/* set by nextopt */
extern char *nextopt_optptr;	/* used by nextopt */

void procargs(int, char **);
void optschanged(void);
void freeparam(struct shparam *);
int nextopt(const char *);
void getoptsreset(const char *);
