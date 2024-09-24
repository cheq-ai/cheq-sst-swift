import XCTest
@testable import Cheq

final class SstTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        Sst.clearCheqUuid()
    }
    
    func testConfigureInvalidDomain() {
        Sst.configure(Config("test", domain: "a b"))
    }
    
    func testClearUUIDWithoutConfigure() {
        Sst.clearCheqUuid()
    }
    
    func testGetUUIDWithoutConfigure() {
        let uuid = Sst.getCheqUuid()
        XCTAssertNil(uuid)
    }
    
    func testPublicTrackEvent() async {
        Sst.configure(Config("test"))
        await Sst.trackEvent(Event("testPublicTrackEvent"))
        await Sst.trackEvent(Event("testPublicTrackEvent2"))
    }
    
    func testTrackEvent() async throws {
        let date = Date(timeIntervalSince1970: 1337)
        Sst.configure(Config("di_demo", domain: "echo.cheqai.workers.dev", debug: true, dateProvider: StaticDateProvider(fixedDate: date)))
        let eventName = "testTrackEvent"
        let customData = CustomData(custom_data: [:],
                                    event_name: "PageView",event_id: "0b11049b2-8afc-4156-9b69-342c692309210",
                                    data_processing_options: ["LDU"],
                                    data_processing_options_country: 0,
                                    data_processing_options_state: 0,
                                    user_data: [
                                        "em": "142d78e466cacab37c3751a6ba0d288ce40db609ce9c49617ea6b24665f1aa9c",
                                        "fbp": "fb.2.1720426909889.614851977197247472"
                                    ],
                                    cards: [PlayingCard(rank: Rank.ace, suit: Suit.spades), PlayingCard(rank: Rank.two, suit: Suit.hearts)],
                                    nillable: nil,
                                    nsnull: NSNull());
        guard let result = await Sst._trackEvent(Event(eventName, data: ["customData": customData], parameters: ["sstOrigin": "blah", "foo":"bar", "test foo": "true&1337 baz="])) else {
            XCTFail("Failed to get valid response")
            return
        }
        let requestDict = decodeJSON(result.requestBody)
        verifyRequest(requestDict, eventName: eventName, date: date)
        let expectedUrl = "https://echo.cheqai.workers.dev/pc/di_demo/sst?foo=bar&sstOrigin=mobile&sstVersion=1.0.0&test%20foo=true%261337%20baz%3D"
        XCTAssertEqual(expectedUrl, result.url, "invalid url")
        XCTAssertNotNil(result.userAgent)
    }
    
    
    func testCustomModel() async throws {
        let foo = Foo()
        let models = try Models(foo)
        let date = Date(timeIntervalSince1970: 2375623857)
        Sst.configure(Config("di_demo", models: models, dateProvider: StaticDateProvider(fixedDate: date)))
        guard let result = await Sst._trackEvent(Event("testCustomModel")) else {
            XCTFail("Failed to get valid response")
            return
        }
        
        let requestDict = decodeJSON(result.requestBody)
        verifyRequest(requestDict, eventName: "testCustomModel", date: date)
        let fooValue = ((requestDict["dataLayer"] as! [String: Any])["__mobileData"] as! [String: Any])["foo"] as! String
        XCTAssertEqual("hello", fooValue)
        let library = ((requestDict["dataLayer"] as! [String: Any])["__mobileData"] as! [String: Any])["library"] as! [String: Any]
        let fooVersion = (library["models"] as! [String: Any])["foo"] as! String
        XCTAssertEqual(foo.version, fooVersion, "invalid model version")
        
    }
    
    func testOverwriteTimestamp() async throws {
        Sst.configure(Config("test"))
        guard let result = await Sst._trackEvent(Event("testOverwriteTimestamp", data: ["__timestamp": "foo"])) else {
            XCTFail("Failed to get valid response")
            return
        }
        let requestDict = decodeJSON(result.requestBody)
        verifyRequest(requestDict, eventName: "testOverwriteTimestamp")
        let timestamp = ((requestDict["events"] as! [[String: Any]])[0]["data"] as! [String: Any])["__timestamp"] as! String
        XCTAssertEqual("foo", timestamp, "invalid overwritten timestamp")
    }
    
    func testDataLayer() async throws {
        Sst.dataLayer.add(key: "card", value: PlayingCard(rank: Rank.queen, suit: Suit.hearts))
        Sst.dataLayer.add(key: "optedIn", value: false)
        Sst.configure(Config("test", dataLayerName: "DATA"))
        guard let result = await Sst._trackEvent(Event("testDataLayer", data: ["__timestamp": "foo"])) else {
            XCTFail("Failed to get valid response")
            return
        }
        let requestDict = decodeJSON(result.requestBody)
        verifyRequest(requestDict, eventName: "testDataLayer")
        let DATADict = (requestDict["dataLayer"] as! [String: Any])["DATA"] as! [String: Any]
        XCTAssertFalse(DATADict["optedIn"] as! Bool)
    }
    
    func testTrackEventInvalidData() async {
        Sst.configure(Config("test"))
        let result = await Sst._trackEvent(Event("testTrackEventInvalidData", data: ["invalidJson": InvalidJSON()]))
        XCTAssertNil(result)
    }
    
    func testTrackEventExpiredCertificate() async {
        Sst.configure(Config("test", domain: "analytics.ensighten.com"))
        let result = await Sst._trackEvent(Event("testTrackEventExpiredCertificate"))
        XCTAssertNil(result)
    }
    
    func testTrackEventInvalidDomain() async {
        Sst.configure(Config("test", domain: "foo.domain"))
        let result = await Sst._trackEvent(Event("testTrackEventInvalidDomain"))
        XCTAssertNil(result)
    }
    
    func testSendErrorHandlesLargeMessage() async {
        Sst.configure(Config("test"))
        let msg = String(repeating: "A", count: 65535)
        let result = await Sst.sendError(msg: msg, fn: "testSendErrorHandlesLargeMessage", errorName: "testSendErrorHandlesLargeMessage")
        XCTAssertTrue(result)
    }
    
    func testSendErrorBadNexus() async {
        Sst.configure(Config("test", nexusHost: "fake.domain"))
        let result = await Sst.sendError(msg: "foo", fn: "bar", errorName: "baz")
        XCTAssertFalse(result)
    }
    
    func testTruncate() {
        XCTAssertEqual("abcdefg...", Sst.truncate("abcdefghijk", 10));
    }
    
    func verifyRequest(_ requestDict:[String: Any], eventName: String, date: Date? = nil) {
        let dataLayer = requestDict["dataLayer"] as! [String: Any]
        XCTAssertNotNil(dataLayer, "missing dataLayer")
        let mobileData = dataLayer["__mobileData"] as! [String: Any]
        XCTAssertNotNil(mobileData, "missing dataLayer.__mobileData")
        let app = mobileData["app"] as! [String: Any]
        XCTAssertNotNil(app, "missing dataLayer.__mobileData.app")
        XCTAssertNotNil(app["build"])
        XCTAssertNotNil(app["name"])
        XCTAssertNotNil(app["namespace"])
        XCTAssertNotNil(app["version"])
        let device = mobileData["device"] as! [String: Any]
        XCTAssertNotNil(device, "missing dataLayer.__mobileData.device")
        let screen = device["screen"] as! [String: Any]
        XCTAssertNotNil(screen)
        XCTAssertNotNil(screen["orientation"])
        XCTAssertNotNil(screen["width"])
        XCTAssertNotNil(screen["height"])
        XCTAssertNotNil(device["id"])
        XCTAssertNotNil(device["manufacturer"])
        XCTAssertNotNil(device["architecture"])
        XCTAssertNotNil(device["model"])
        let os = device["os"] as! [String: Any]
        XCTAssertNotNil(os)
        XCTAssertNotNil(os["name"])
        XCTAssertNotNil(os["version"])
        let library = mobileData["library"] as! [String: Any]
        XCTAssertNotNil(library, "missing dataLayer.__mobileData.library")
        XCTAssertNotNil(library["name"])
        XCTAssertNotNil(library["version"])
        XCTAssertNotNil(library["models"])
        
        let events = requestDict["events"] as! [[String: Any]]
        XCTAssertNotNil(events, "missing events")
        XCTAssertEqual(1, events.count, "invalid event count")
        let event = events[0]
        XCTAssertEqual(eventName, event["name"] as! String, "invalid event name")
        let eventData = event["data"] as! [String: Any]
        if let date = date {
            XCTAssertEqual(Int(date.timeIntervalSince1970 * 1000), eventData["__timestamp"] as! Int, "invalid __timestamp")
        }
        
        let settings = requestDict["settings"] as! [String: Any]
        XCTAssertNotNil(settings, "missing settings")
        XCTAssertNotNil(settings["publishPath"])
        XCTAssertNotNil(settings["nexusHost"])
        
        let virtualBrowser = requestDict["virtualBrowser"] as! [String: Any]
        XCTAssertNotNil(virtualBrowser, "missing virtualBrowser")
        XCTAssertNotNil(virtualBrowser["height"])
        XCTAssertNotNil(virtualBrowser["width"])
        XCTAssertNotNil(virtualBrowser["language"])
        XCTAssertNotNil(virtualBrowser["timezone"])
    }
    
    func decodeJSON(_ result: String) -> [String: Any] {
        if let jsonData = result.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
            } catch {
                XCTFail("Failed to decode JSON: \(error)")
            }
        }
        XCTFail("Failed to get data")
        return [:]
    }
    
    struct CustomData {
        
        let custom_data: [String: String]
        let event_name: String
        let event_id: String
        let data_processing_options: [String]
        let data_processing_options_country: Int
        let data_processing_options_state: Int
        let user_data: [String: String]
        let cards: [PlayingCard]
        let nillable: Any?
        let nsnull: NSNull
    }
    
    enum Rank: Int {
        case two = 2
        case three, four, five, six, seven, eight, nine, ten
        case jack, queen, king, ace
    }
    
    enum Suit {
        case spades, hearts, diamonds, clubs
    }
    
    struct PlayingCard {
        let rank: Rank
        let suit: Suit
    }
    
    class Foo : Model {
        override var key: String {
            get { "foo" }
        }
        override var version: String {
            get { "1.33.7" }
        }
        override func get(event: Event, sst: Sst) async -> Any {
            return "hello"
        }
    }
    
    struct InvalidJSON: Encodable {
        func encode(to encoder: Encoder) throws {
        }
    }
}