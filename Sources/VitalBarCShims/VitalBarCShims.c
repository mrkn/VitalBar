#include "VitalBarCShims.h"

#include <errno.h>
#include <sys/syscall.h>
#include <unistd.h>

int32_t vitalbar_current_memory_pressure_level(int32_t *out_level) {
    if (out_level == NULL) {
        return EINVAL;
    }

    int level = -1;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    long result = syscall(SYS_memorystatus_get_level, &level);
#pragma clang diagnostic pop
    if (result != 0) {
        return errno != 0 ? errno : EIO;
    }

    *out_level = level;
    return 0;
}
