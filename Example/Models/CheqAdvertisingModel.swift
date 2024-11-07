import Cheq
#if canImport(AdSupport)
import AdSupport
#endif
import AppTrackingTransparency

class CheqAdvertisingModel: Model {
    override var key: String {
        get { "advertising" }
    }
    
    override func get(event: Event, sst: Sst) async -> Any {
        var enabled = false
        var id = "Unknown"
#if canImport(AdSupport)
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            enabled = true
            id = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
#endif
        return AdvertisingInfo(id: id, enabled: enabled)
    }
}

struct AdvertisingInfo: Encodable {
    let id: String
    let enabled: Bool
}
