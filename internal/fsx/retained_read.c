#define _GNU_SOURCE
#include "moonbit.h"
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#ifdef __APPLE__
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

/* Walk an already validated relative name from an anchored directory handle.
 * Every component is opened without following links. Nonblocking opens ensure
 * a substituted FIFO cannot hang the host. No Book files are created/changed. */
MOONBIT_FFI_EXPORT int
moonbit_moonbook_retained_read(moonbit_bytes_t root, moonbit_bytes_t relative,
                              moonbit_bytes_t output, int capacity) {
  int dir = open((const char *)root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (dir < 0) return -1;
  char *name = strdup((const char *)relative);
  if (!name) { close(dir); return -1; }
  char *part = name;
  int file = -1;
  for (;;) {
    char *slash = strchr(part, '/');
    if (slash) *slash = '\0';
    if (!*part || !strcmp(part, ".") || !strcmp(part, "..")) break;
    if (slash) {
      int next = openat(dir, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
      if (next < 0) break;
      close(dir); dir = next; part = slash + 1;
    } else {
      file = openat(dir, part, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
      break;
    }
  }
  free(name); close(dir);
  if (file < 0) return -1;
  struct stat before, after;
  int size = 0, result = -1;
  if (fstat(file, &before) || !S_ISREG(before.st_mode) ||
      before.st_size < 0 || before.st_size >= capacity) goto done;
  while (size < capacity) {
    ssize_t count = read(file, output + size, capacity - size);
    if (count < 0) goto done;
    if (!count) break;
    size += (int)count;
  }
  if (size >= capacity || fstat(file, &after) ||
      before.st_dev != after.st_dev || before.st_ino != after.st_ino ||
      before.st_size != after.st_size || size != after.st_size ||
      before.st_mtim.tv_sec != after.st_mtim.tv_sec ||
      before.st_mtim.tv_nsec != after.st_mtim.tv_nsec ||
      before.st_ctim.tv_sec != after.st_ctim.tv_sec ||
      before.st_ctim.tv_nsec != after.st_ctim.tv_nsec) goto done;
  result = size;
done:
  close(file);
  return result;
}
