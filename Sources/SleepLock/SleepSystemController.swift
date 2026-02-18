import Foundation
import IOKit.pwr_mgt

enum SleepSystemController {
    static func requestSystemSleep() {
        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard port != 0 else { return }
        IOPMSleepSystem(port)
    }
}
