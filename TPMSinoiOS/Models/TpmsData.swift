import Foundation

public enum BleConnectionState: Equatable {
    case idle
    case scanning
    case connecting
    case connected
    case disconnected(String)
    case error(String)
}

public enum TireKey: String, CaseIterable, Identifiable, Codable {
    case FL = "FL"
    case FR = "FR"
    case RL = "RL"
    case RR = "RR"

    public var id: String { self.rawValue }

    public var displayName: String {
        switch self {
        case .FL: return "Front Left"
        case .FR: return "Front Right"
        case .RL: return "Rear Left"
        case .RR: return "Rear Right"
        }
    }
}

public struct TpmsData: Identifiable, Equatable, Codable {
    public var id: UUID = UUID()
    public var pressurePsi: Float
    public var temperatureCelsius: Float
    public var timestamp: Int64
    public var sensorId: String?
    public var isBatteryGood: Bool
    public var rssiDbm: Int
    public var isSimulated: Bool
    public var isValid: Bool
    public var silencedAbnormalities: Int

    public init(
        pressurePsi: Float = 0.0,
        temperatureCelsius: Float = 0.0,
        timestamp: Int64 = 0,
        sensorId: String? = nil,
        isBatteryGood: Bool = true,
        rssiDbm: Int = -60,
        isSimulated: Bool = false,
        isValid: Bool = false,
        silencedAbnormalities: Int = 0
    ) {
        self.pressurePsi = pressurePsi
        self.temperatureCelsius = temperatureCelsius
        self.timestamp = timestamp
        self.sensorId = sensorId
        self.isBatteryGood = isBatteryGood
        self.rssiDbm = rssiDbm
        self.isSimulated = isSimulated
        self.isValid = isValid
        self.silencedAbnormalities = silencedAbnormalities
    }
}
