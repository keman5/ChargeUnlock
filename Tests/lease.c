#include "../Runner/Lease.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(CUCanPulse(100, 99, true, true));
    assert(!CUCanPulse(100, 0, true, true));
    assert(!CUCanPulse(100, 92, true, true));
    assert(!CUCanPulse(100, 101, true, true));
    assert(!CUCanPulse(100, 99, false, true));
    assert(!CUCanPulse(100, 99, true, false));
    assert(CUCanPulse(108, 107, true, true));
    puts("PASS: lease expiry, unplug, lock, missing heartbeat, reconnect");
}
