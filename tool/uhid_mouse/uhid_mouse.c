// A virtual USB mouse for Android emulators, whose `input mouse` is ignored by
// apps' hover handling. Build static, push to /data/local/tmp, run as root:
//   gcc -static -O2 -o uhid_mouse uhid_mouse.c
// stdin: "go DX DY" moves in small steps, "d" presses, "u" releases.
#include <fcntl.h>
#include <linux/uhid.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const unsigned char desc[] = {
    0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0x09, 0x01, 0xA1, 0x00, 0x05, 0x09, 0x19, 0x01, 0x29, 0x03,
    0x15, 0x00, 0x25, 0x01, 0x95, 0x03, 0x75, 0x01, 0x81, 0x02, 0x95, 0x01, 0x75, 0x05, 0x81, 0x03,
    0x05, 0x01, 0x09, 0x30, 0x09, 0x31, 0x15, 0x81, 0x25, 0x7F, 0x75, 0x08, 0x95, 0x02, 0x81, 0x06,
    0xC0, 0xC0};
static int fd;
static int buttons;

static void report(int dx, int dy) {
  struct uhid_event e;
  memset(&e, 0, sizeof e);
  e.type = UHID_INPUT2;
  e.u.input2.size = 3;
  e.u.input2.data[0] = buttons;
  e.u.input2.data[1] = (signed char)dx;
  e.u.input2.data[2] = (signed char)dy;
  if (write(fd, &e, sizeof e) < 0) perror("write");
}

int main(void) {
  setvbuf(stdout, NULL, _IONBF, 0);
  fd = open("/dev/uhid", O_RDWR | O_CLOEXEC);
  if (fd < 0) {
    perror("/dev/uhid");
    return 1;
  }
  struct uhid_event e;
  memset(&e, 0, sizeof e);
  e.type = UHID_CREATE2;
  strcpy((char *)e.u.create2.name, "uhid-mouse");
  e.u.create2.rd_size = sizeof desc;
  memcpy(e.u.create2.rd_data, desc, sizeof desc);
  e.u.create2.bus = 3;
  e.u.create2.vendor = 0x1234;
  e.u.create2.product = 0x5678;
  if (write(fd, &e, sizeof e) < 0) perror("create");
  sleep(1);
  puts("ready");
  char line[64];
  while (fgets(line, sizeof line, stdin)) {
    int dx, dy;
    if (sscanf(line, "go %d %d", &dx, &dy) == 2) {
      while (dx || dy) {
        int sx = dx > 4 ? 4 : dx < -4 ? -4 : dx, sy = dy > 4 ? 4 : dy < -4 ? -4 : dy;
        report(sx, sy);
        dx -= sx;
        dy -= sy;
        usleep(6000);
      }
    } else if (line[0] == 'd') {
      buttons = 1;
      report(0, 0);
    } else if (line[0] == 'u') {
      buttons = 0;
      report(0, 0);
    }
    puts("ok");
  }
  return 0;
}
