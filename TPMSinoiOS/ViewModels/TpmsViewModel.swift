import Foundation
import Combine
import AVFoundation
import AudioToolbox

public class TpmsViewModel: ObservableObject {
    @Published public var connectionState: BleConnectionState = .idle
    @Published public var tyreStatuses: [TireKey: TpmsData] = [:]
    @Published public var sensorPairs: [TireKey: String] = [:]
    @Published public var tpmsData: TpmsData? = nil
    @Published public var logsHistory: [TpmsData] = []

    // Settings
    @Published public var minPressureFront: Float = 28.0
    @Published public var nominalPressureFront: Float = 33.0
    @Published public var maxPressureFront: Float = 40.0
    @Published public var maxTempFront: Float = 65.0

    @Published public var minPressureRear: Float = 28.0
    @Published public var nominalPressureRear: Float = 33.0
    @Published public var maxPressureRear: Float = 40.0
    @Published public var maxTempRear: Float = 65.0

    @Published public var usePsi: Bool = true
    @Published public var useCelsius: Bool = true
    @Published public var useEngineeringDashboard: Bool = false
    @Published public var vibrateOnAlarm: Bool = true
    @Published public var loudDisconnectionAlarm: Bool = true
    @Published public var enableDisconnectionAlarm: Bool = true
    @Published public var isSimulationMode: Bool = false

    @Published public var showConnectionLostWarning: Bool = false
    @Published public var simulationRlPressurePsi: Float = 32.0

    public var bleManager = BleManager()
    private var cancellables = Set<AnyCancellable>()
    private var simulationTimer: Timer? = nil

    public init() {
        self.tyreStatuses = [
            .FL: TpmsData(isValid: false),
            .FR: TpmsData(isValid: false),
            .RL: TpmsData(isValid: false),
            .RR: TpmsData(isValid: false)
        ]

        loadSettings()

        bleManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.connectionState = state
                if case .disconnected = state, self.enableDisconnectionAlarm {
                    self.showConnectionLostWarning = true
                    self.playDisconnectionTone()
                } else if case .connected = state {
                    self.showConnectionLostWarning = false
                }
            }
            .store(in: &cancellables)

        bleManager.$latestPacket
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                guard let self = self, !self.isSimulationMode else { return }
                self.processPacket(packet)
            }
            .store(in: &cancellables)
    }

    public func startMonitoring() {
        if isSimulationMode {
            startSimulationTimer()
        } else {
            bleManager.startMonitoring()
        }
    }

    public func stopMonitoring() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        bleManager.stopMonitoring()
    }

    public func setSimulationMode(_ enabled: Bool) {
        self.isSimulationMode = enabled
        if enabled {
            stopMonitoring()
            startSimulationTimer()
        } else {
            simulationTimer?.invalidate()
            simulationTimer = nil
            eraseSensorList()
            startMonitoring()
        }
    }

    private func startSimulationTimer() {
        simulationTimer?.invalidate()
        var simIndex = 0
        let sensorIds = ["80ABCDE0", "80ABCDE1", "80ABCDE2", "80ABCDE3"]

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let sId = sensorIds[simIndex]
            simIndex = (simIndex + 1) % sensorIds.count

            let matchingKey = self.sensorPairs.first(where: { $0.value == sId })?.key
            let pPsi = (matchingKey == .RL) ? self.simulationRlPressurePsi : (32.0 + Float.random(in: -2...2))

            let packet = TpmsData(
                pressurePsi: pPsi,
                temperatureCelsius: 24.0 + Float.random(in: -1...1),
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                sensorId: sId,
                isBatteryGood: true,
                rssiDbm: -65,
                isSimulated: true,
                isValid: true
            )
            self.processPacket(packet)
        }
    }

    private func processPacket(_ packet: TpmsData) {
        self.tpmsData = packet

        if BleConstants.ENABLE_LOG_COLLECTION {
            self.logsHistory.insert(packet, at: 0)
            if self.logsHistory.count > 500 { self.logsHistory.removeLast() }
        }

        if let matchingKey = self.sensorPairs.first(where: { $0.value == packet.sensorId })?.key {
            let ab = getAbnormalities(for: matchingKey, data: packet)
            let prevSilenced = self.tyreStatuses[matchingKey]?.silencedAbnormalities ?? 0
            let newSilenced = prevSilenced & ab

            var updated = packet
            updated.silencedAbnormalities = newSilenced
            self.tyreStatuses[matchingKey] = updated
        }

        updateSoundAlarmState()
    }

    public func getAbnormalities(for key: TireKey, data: TpmsData) -> Int {
        guard data.isValid, data.timestamp > 0 else { return 0 }
        let isFront = (key == .FL || key == .FR)
        let minP = isFront ? minPressureFront : minPressureRear
        let maxP = isFront ? maxPressureFront : maxPressureRear
        let maxT = isFront ? maxTempFront : maxTempRear

        var abnormal = 0
        if data.pressurePsi < minP { abnormal |= 1 }      // Bit 0: Low Pressure
        if data.pressurePsi > maxP { abnormal |= 2 }      // Bit 1: High Pressure
        if data.temperatureCelsius > maxT { abnormal |= 4 } // Bit 2: High Temp
        if !data.isBatteryGood { abnormal |= 8 }         // Bit 3: Low Battery
        return abnormal
    }

    public func updateSoundAlarmState() {
        var shouldAlert = false
        for (key, data) in tyreStatuses {
            let abnormal = getAbnormalities(for: key, data: data)
            let unsilenced = abnormal & ~data.silencedAbnormalities
            if unsilenced != 0 {
                shouldAlert = true
                break
            }
        }
        if shouldAlert {
            playShortAlertSound()
        }
    }

    public func silenceAlarms() {
        self.showConnectionLostWarning = false
        for (key, data) in tyreStatuses {
            let ab = getAbnormalities(for: key, data: data)
            if ab != 0 {
                tyreStatuses[key]?.silencedAbnormalities = ab
            }
        }
    }

    public func assignSensorToTire(_ tireKey: TireKey, sensorId: String) {
        for (key, val) in sensorPairs where val == sensorId {
            sensorPairs.removeValue(forKey: key)
        }
        sensorPairs[tireKey] = sensorId
        saveSettings()
    }

    public func eraseSensorList() {
        sensorPairs.removeAll()
        tyreStatuses = [
            .FL: TpmsData(isValid: false),
            .FR: TpmsData(isValid: false),
            .RL: TpmsData(isValid: false),
            .RR: TpmsData(isValid: false)
        ]
        logsHistory.removeAll()
        saveSettings()
    }

    public func playPacketClickSound() {
        AudioServicesPlaySystemSound(1104) // iOS TOCK click sound
    }

    public func playDisconnectionTone() {
        AudioServicesPlaySystemSound(1005) // iOS Warning alert tone
    }

    public func playShortAlertSound() {
        AudioServicesPlaySystemSound(1007) // iOS Alarm chime
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        minPressureFront = defaults.float(forKey: "minPFront") == 0 ? 28.0 : defaults.float(forKey: "minPFront")
        nominalPressureFront = defaults.float(forKey: "nomPFront") == 0 ? 33.0 : defaults.float(forKey: "nomPFront")
        maxPressureFront = defaults.float(forKey: "maxPFront") == 0 ? 40.0 : defaults.float(forKey: "maxPFront")
        maxTempFront = defaults.float(forKey: "maxTFront") == 0 ? 65.0 : defaults.float(forKey: "maxTFront")

        minPressureRear = defaults.float(forKey: "minPRear") == 0 ? 28.0 : defaults.float(forKey: "minPRear")
        nominalPressureRear = defaults.float(forKey: "nomPRear") == 0 ? 33.0 : defaults.float(forKey: "nomPRear")
        maxPressureRear = defaults.float(forKey: "maxPRear") == 0 ? 40.0 : defaults.float(forKey: "maxPRear")
        maxTempRear = defaults.float(forKey: "maxTRear") == 0 ? 65.0 : defaults.float(forKey: "maxTRear")

        usePsi = defaults.object(forKey: "usePsi") == nil ? true : defaults.bool(forKey: "usePsi")
        useCelsius = defaults.object(forKey: "useCelsius") == nil ? true : defaults.bool(forKey: "useCelsius")
        useEngineeringDashboard = defaults.bool(forKey: "useEngDash")
        vibrateOnAlarm = defaults.object(forKey: "vibrateOnAlarm") == nil ? true : defaults.bool(forKey: "vibrateOnAlarm")
        loudDisconnectionAlarm = defaults.object(forKey: "loudDiscAlarm") == nil ? true : defaults.bool(forKey: "loudDiscAlarm")
        enableDisconnectionAlarm = defaults.object(forKey: "enableDiscAlarm") == nil ? true : defaults.bool(forKey: "enableDiscAlarm")
        isSimulationMode = defaults.bool(forKey: "isSimMode")
    }

    public func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(minPressureFront, forKey: "minPFront")
        defaults.set(nominalPressureFront, forKey: "nomPFront")
        defaults.set(maxPressureFront, forKey: "maxPFront")
        defaults.set(maxTempFront, forKey: "maxTFront")

        defaults.set(minPressureRear, forKey: "minPRear")
        defaults.set(nominalPressureRear, forKey: "nomPRear")
        defaults.set(maxPressureRear, forKey: "maxPRear")
        defaults.set(maxTempRear, forKey: "maxTRear")

        defaults.set(usePsi, forKey: "usePsi")
        defaults.set(useCelsius, forKey: "useCelsius")
        defaults.set(useEngineeringDashboard, forKey: "useEngDash")
        defaults.set(vibrateOnAlarm, forKey: "vibrateOnAlarm")
        defaults.set(loudDisconnectionAlarm, forKey: "loudDiscAlarm")
        defaults.set(enableDisconnectionAlarm, forKey: "enableDiscAlarm")
        defaults.set(isSimulationMode, forKey: "isSimMode")
    }
}
