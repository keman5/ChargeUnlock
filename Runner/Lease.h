#include <stdbool.h>

static inline bool CUCanPulse(double now, double heartbeat, bool powered, bool unlocked) {
    return powered && unlocked && heartbeat > 0 && now >= heartbeat && now - heartbeat < 8;
}
