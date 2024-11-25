import SwiftUI
import Cheq

@main
struct SimpleSwiftUIApp: App {
    init() {
        // track launch count
        if var launchCount = Sst.dataLayer.get("launchCount") as? Int {
            launchCount += 1
            Sst.dataLayer.add(key: "launchCount", value: launchCount)
        } else {
            Sst.dataLayer.add(key: "launchCount", value: 1)
        }
        SimpleSwiftUIApp.initializeSst()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    static func initializeSst() {
        Sst.configure(Config("mobile_demo",
                             models: try! Models.default().add(CheqAdvertisingModel()),
                             debug: true))
    }
}

class Static : Model {
    override var key: String {
        "custom_static_model"
    }
    override func get(event: Event, sst: Sst) async -> Any {
        return ["foo": "bar"]
    }
}

struct BadEncodable: Encodable {
    func encode(to encoder: Encoder) throws {
    }
}
