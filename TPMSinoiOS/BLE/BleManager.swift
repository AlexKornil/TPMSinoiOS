import Foundation
import CoreBluetooth
import Combine

public class BleManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published public var connectionState: BleConnectionState = .idle
    @Published public var latestPacket: TpmsData? = nil

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var isMonitoring: Bool = false

    public override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    public func startMonitoring() {
        self.isMonitoring = true
        if centralManager.state == .poweredOn {
            startScan()
        }
    }

    public func stopMonitoring() {
        self.isMonitoring = false
        stopScan()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
        DispatchQueue.main.async {
            self.connectionState = .idle
        }
    }

    public func startScan() {
        guard centralManager.state == .poweredOn else { return }
        guard connectionState != .connected && connectionState != .connecting else { return }

        DispatchQueue.main.async {
            self.connectionState = .scanning
        }

        // Scan for TPMS Dispatcher ESS Service
        centralManager.scanForPeripherals(
            withServices: [BleConstants.ESS_SERVICE_UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func stopScan() {
        centralManager.stopScan()
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if isMonitoring {
                startScan()
            }
        } else {
            DispatchQueue.main.async {
                self.connectionState = .error("Bluetooth powered off")
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        if name.lowercased().contains("dispatcher") || name.lowercased().contains("tpms") || true {
            stopScan()
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            DispatchQueue.main.async {
                self.connectionState = .connecting
            }
            centralManager.connect(peripheral, options: nil)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
        peripheral.discoverServices([BleConstants.ESS_SERVICE_UUID])
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.connectedPeripheral = nil
        DispatchQueue.main.async {
            self.connectionState = .disconnected("Connection lost")
        }
        if isMonitoring {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isMonitoring {
                    self.startScan()
                }
            }
        }
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == BleConstants.ESS_SERVICE_UUID {
                peripheral.discoverCharacteristics(
                    [BleConstants.TPMS_DATA_CHAR_UUID, BleConstants.TPMS_CONFIG_CHAR_UUID],
                    for: service
                )
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == BleConstants.TPMS_DATA_CHAR_UUID {
                peripheral.setNotifyValue(true, for: char)
            } else if char.uuid == BleConstants.TPMS_CONFIG_CHAR_UUID {
                sendConfiguration(peripheral: peripheral, characteristic: char)
            }
        }
    }

    private func sendConfiguration(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let modeByte = BleConstants.DISPATCHER_CONFIG_MODE
        let modeData = Data([modeByte])
        peripheral.writeValue(modeData, for: characteristic, type: .withResponse)

        if modeByte != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let configData = Data(BleConstants.DISPATCHER_CONFIG_DATA)
                peripheral.writeValue(configData, for: characteristic, type: .withResponse)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == BleConstants.TPMS_DATA_CHAR_UUID, let value = characteristic.value else { return }
        parsePacket(data: value)
    }

    private func parsePacket(data: Data) {
        guard data.count >= 11 else { return }

        // Checksum validation
        var sum: Int = 0
        for i in 0..<8 {
            sum += Int(data[i])
        }
        let checksum = UInt8(sum & 0xFF)
        guard checksum == data[8] else { return }

        // Sensor ID (4 bytes Hex)
        let sensorIdHex = data.subdata(in: 0..<4).map { String(format: "%02X", $0) }.joined()

        // Pressure (byte 4)
        let rawPressure = Float(data[4])
        var pressurePsi = (rawPressure * 0.51) - 0.9
        if pressurePsi < 0 { pressurePsi = 0 }
        pressurePsi = round(pressurePsi)

        // Temperature (byte 6)
        let rawTemp = Float(data[6])
        let tempCelsius = rawTemp - 56.0

        // Battery (byte 7)
        let isBatteryGood = (data[7] & 0x80) == 0

        // RSSI
        let rawRssi = Int8(bitPattern: data[9])
        let calculatedRssi = Int((rawRssi / 2) - 74)

        let packet = TpmsData(
            pressurePsi: pressurePsi,
            temperatureCelsius: tempCelsius,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            sensorId: sensorIdHex,
            isBatteryGood: isBatteryGood,
            rssiDbm: calculatedRssi,
            isSimulated: false,
            isValid: true
        )

        DispatchQueue.main.async {
            self.connectionState = .connected
            self.latestPacket = packet
        }
    }
}
