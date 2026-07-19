#include "moonbit.h"
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/stat.h>

MOONBIT_FFI_EXPORT
int
moonbit_moonbook_fs_stat_sizeof() {
  return sizeof(struct stat);
}

MOONBIT_FFI_EXPORT
int
moonbit_moonbook_fs_stat_sync(moonbit_bytes_t path, moonbit_bytes_t buf) {
  errno = 0;
  int result = stat((const char *)path, (struct stat *)buf);
  if (result == -1) {
    return errno;
  } else {
    return 0;
  }
}

MOONBIT_FFI_EXPORT
int64_t
moonbit_moonbook_fs_stat_get_mtime(moonbit_bytes_t buf) {
  struct stat *st = (struct stat *)buf;
  return (int64_t)st->st_mtime;
}

MOONBIT_FFI_EXPORT
int
moonbit_moonbook_fs_atomic_replace(moonbit_bytes_t source,
                                   moonbit_bytes_t destination) {
  errno = 0;
  if (rename((const char *)source, (const char *)destination) == -1) {
    return errno;
  }
  return 0;
}
