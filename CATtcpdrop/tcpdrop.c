/* $OpenBSD: tcpdrop.c,v 1.4 2004/05/22 23:55:22 deraadt Exp $ */

/*-
 * Copyright (c) 2004 Markus Friedl <markus@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* $FreeBSD: src/usr.sbin/tcpdrop/tcpdrop.c,v 1.2 2005/02/14 07:37:51 maxim Exp $ */

/* Ported to Solaris by Ceri Davies <ceri@submonkey.net>, 2006-2008
 *  Parts likely under the CDDL (search forward for "CDDL" to see them),
 *  a copy of which is provided in the file OPENSOLARIS.LICENSE.
 */

#include <sys/fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/stropts.h>
#include <netinet/in.h>
#include <inet/tcp.h>

#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stropts.h>
#include <unistd.h>



/*
 * Drop a tcp connection.
 */
int
main(int argc, char *argv[])
{
	struct addrinfo hints, *ail, *aif, *laddr, *faddr;
	/* addrs[0] is a foreign socket, addrs[1] is a local one. */
	struct sockaddr_storage addrs[2];
	struct strioctl ioc;
	tcp_ioc_abort_conn_t conn;
	int error = 0;
	int fd, gaierr, rval = 0;
	char fhbuf[NI_MAXHOST], fsbuf[NI_MAXSERV], lhbuf[NI_MAXHOST],
	    lsbuf[NI_MAXSERV];

	if (argc != 5) {
		fprintf(stderr, "usage: tcpdrop laddr lport faddr fport\n");
		exit(1);
	}

	memset(&conn,  0, sizeof(conn));
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	if ((gaierr = getaddrinfo(argv[1], argv[2], &hints, &laddr)) != 0) {
		fprintf(stderr, "%s port %s: %s", argv[1], argv[2],
		    gai_strerror(gaierr));
		exit(1);
	}
	if ((gaierr = getaddrinfo(argv[3], argv[4], &hints, &faddr)) != 0) {
		freeaddrinfo(laddr);
		fprintf(stderr, "%s port %s: %s", argv[3], argv[4],
		    gai_strerror(gaierr));
		exit(1);
	}
	for (ail = laddr; ail; ail = ail->ai_next) {
		for (aif = faddr; aif; aif = aif->ai_next) {
			if (ail->ai_family != aif->ai_family)
				continue;
			memcpy(&addrs[0], aif->ai_addr, aif->ai_addrlen);
			memcpy(&addrs[1], ail->ai_addr, ail->ai_addrlen);
			if (getnameinfo(aif->ai_addr, aif->ai_addrlen,
			    fhbuf, sizeof(fhbuf),
			    fsbuf, sizeof(fsbuf),
			    NI_NUMERICHOST | NI_NUMERICSERV) == -1) {
				fprintf(stderr, "getnameinfo");
				exit(1);
			    }
			if (getnameinfo(ail->ai_addr, ail->ai_addrlen,
			    lhbuf, sizeof(lhbuf),
			    lsbuf, sizeof(lsbuf),
			    NI_NUMERICHOST | NI_NUMERICSERV) == -1) {
				fprintf(stderr, "getnameinfo");
				exit(1);
			    }

/* This block here from
   http://cvs.opensolaris.org/source/xref/on/usr/src/cmd/zoneadmd/vplat.c
   and therefore possibly covered by the CDDL */

			conn.ac_remote = addrs[0];
			conn.ac_local  = addrs[1];
			conn.ac_start = TCPS_SYN_SENT;
			conn.ac_end = TCPS_TIME_WAIT;

			ioc.ic_cmd = TCP_IOC_ABORT_CONN;
			ioc.ic_timout = -1;
			ioc.ic_len = sizeof(conn);
			ioc.ic_dp = (char *)&conn;

			if ((fd = open("/dev/tcp", O_RDONLY)) < 0) {
				fprintf(stderr, "unable to open /dev/tcp\n");
				rval++;
				break;
			}

			error = ioctl(fd, I_STR, &ioc);
			(void) close(fd);

/* End code block cribbed from OpenSolaris */

			if (error >= 0) {
				printf("%s:%s <-> %s:%s: dropped\n",
				    lhbuf, lsbuf, fhbuf, fsbuf);
			} else { /* error == -1 is the only other
				     possible case, but be safe.  */
				switch(errno) {
				    case EPERM:
					fprintf(stderr, "Permission denied\n");
					break;
				    case ENOENT:
					fprintf(stderr, "Connection %s:%s <-> %s:%s not found\n",
					    lhbuf, lsbuf, fhbuf, fsbuf);
					break;
				    default:
					fprintf(stderr, "Dropping %s:%s <-> %s:%s failed\n",
					    lhbuf, lsbuf, fhbuf, fsbuf);
					fprintf(stderr, "error was %d\n", error);
					break;
				}
				rval++;
			}
		}
	}
	freeaddrinfo(laddr);
	freeaddrinfo(faddr);
	exit(rval);
}
