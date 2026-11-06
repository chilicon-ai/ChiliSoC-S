// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S sim :: rbb.c (DPI-C, simulation only)
//
// OpenOCD remote_bitbang server for chilisocs_tb (+rbb_port=<n>): OpenOCD
// (adapter driver remote_bitbang) connects over TCP and sends one character
// per JTAG pin change; the testbench calls rbb_step() every few clk cycles
// and drives the JTAG pins from its result.
//
//   '0'..'7'  set tck / tms / tdi ('0' + 4 * tck + 2 * tms + tdi)
//   'R'       read tdo: answer '0' or '1'
//   'r'..'u'  resets: 'r' + 2 * trst + srst (1 = asserted)
//   'B' 'b'   blink (ignored)
//   'Q'       quit: the connection closes, the server accepts a new one
// -----------------------------------------------------------------------------
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#ifdef __cplusplus                  // Verilator compiles this file as C++
extern "C" {
#endif

static int lfd = -1;    // listening socket
static int cfd = -1;    // OpenOCD connection
static int pins;        // bit 0 tck, 1 tms, 2 tdi, 3 trst asserted, 4 srst asserted

// listen on 127.0.0.1:port; 0 on success
int rbb_open(int port)
{
  struct sockaddr_in a;
  int one = 1;
  lfd = socket(AF_INET, SOCK_STREAM, 0);
  if (lfd < 0)
    return -1;
  setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
  memset(&a, 0, sizeof a);
  a.sin_family = AF_INET;
  a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  a.sin_port = htons((unsigned short)port);
  if (bind(lfd, (struct sockaddr *)&a, sizeof a) || listen(lfd, 1)) {
    perror("rbb: bind / listen");
    close(lfd);
    lfd = -1;
    return -1;
  }
  fcntl(lfd, F_SETFL, O_NONBLOCK);
  printf("rbb: listening on port %d\n", port);
  fflush(stdout);
  return 0;
}

// handle OpenOCD's characters until tck changes or none is waiting; returns
// the pins (bit 0 tck, 1 tms, 2 tdi, 3 trst, 4 srst; 1 = asserted for resets)
int rbb_step(int tdo)
{
  if (lfd < 0)
    return pins;
  if (cfd < 0) {
    int one = 1;
    cfd = accept(lfd, NULL, NULL);
    if (cfd < 0)
      return pins;
    fcntl(cfd, F_SETFL, O_NONBLOCK);
    setsockopt(cfd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);
    printf("rbb: OpenOCD connected\n");
    fflush(stdout);
  }
  for (;;) {
    char c;
    ssize_t n = recv(cfd, &c, 1, 0);
    if (n == 0 || (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK)) {
      close(cfd);
      cfd = -1;
      return pins;
    }
    if (n < 0)
      return pins;
    if (c >= '0' && c <= '7') {
      int tck_old = pins & 1;
      pins = (pins & ~7) | (c - '0') >> 2 | ((c - '0') & 2) | ((c - '0') & 1) << 2;
      if ((pins & 1) != tck_old)
        return pins;
    } else if (c == 'R') {
      char r = tdo ? '1' : '0';
      while (send(cfd, &r, 1, 0) < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
        ;
    } else if (c >= 'r' && c <= 'u') {
      int k = c - 'r';
      pins = (pins & 7) | (k & 2 ? 8 : 0) | (k & 1 ? 16 : 0);
    } else if (c == 'Q') {
      close(cfd);
      cfd = -1;
      return pins;
    }
  }
}

#ifdef __cplusplus
}
#endif
