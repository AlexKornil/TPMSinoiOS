import Foundation
import CoreBluetooth

public struct BleConstants {
    public static let DISPATCHER_DEVICE_NAME = "Dispatcher"

    // Custom Unique 128-bit TPMS Service UUID
    public static let ESS_SERVICE_UUID = CBUUID(string: "7f2d8e41-0b3a-4f98-9e5c-1a8b7c6d5e4f")

    // Custom Unique 128-bit TPMS Data Characteristic UUID (Dispatcher TX -> Phone RX)
    public static let TPMS_DATA_CHAR_UUID = CBUUID(string: "c3e9b1a5-8f2d-4e71-a9c4-6b0d8e2f1a3b")

    // Custom Unique 128-bit TPMS Config Characteristic UUID (Phone TX -> Dispatcher RX)
    public static let TPMS_CONFIG_CHAR_UUID = CBUUID(string: "e5a7d3f2-1b4c-4e89-8d0f-2c3b4a5e6f7a")

    // Client Characteristic Configuration Descriptor (CCCD)
    public static let CCCD_UUID = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")

    // Hardwired Dispatcher Configuration Mode (1 byte, if 0 no following 64-byte payload sent)
    public static let DISPATCHER_CONFIG_MODE: UInt8 = 0

    // Hardwired Dispatcher Configuration Data (64 bytes, numbers 1 to 64)
    public static let DISPATCHER_CONFIG_DATA: [UInt8] = Array(1...64)

    // Flag to disable the Log Screen/Button and PREVENT log collection
    public static let ENABLE_LOG_COLLECTION: Bool = true
}
