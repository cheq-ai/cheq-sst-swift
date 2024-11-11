import Foundation
import os
import WebKit

/// CHEQ Server-Side Tagging (SST) framework
///
/// Provides functionality for configuring SST and tracking events
public class Sst {
    static internal let log = Logger(subsystem: "Cheq", category: "Sst")
    static internal let baseParams: [String : String] = ["sstOrigin": "mobile", "sstVersion": "1.0.0"]
    static internal var uaTask:Task<Void, Never> {
        let task = Task {
            let userAgent = await MainActor.run {
                let config = WKWebViewConfiguration()
                config.limitsNavigationsToAppBoundDomains = true
                config.preferences.javaScriptEnabled = false
                let webView = WKWebView(frame: CGRect(), configuration: config)
                return webView.value(forKey: "userAgent") as? String
            }
            Sst.instance?.userAgent = userAgent
        }
        return task
    }
    
    static internal var instance:Sst?
    
    /// Persistent data layer
    public static let dataLayer = DataLayer()
    
    let config:Config
    var userAgent: String?
    
    init(config: Config) {
        self.config = config
    }
    
    /// Configures SST
    /// - Parameter config: The configuration object
    public static func configure(_ config: Config) {
        guard URL(string: "https://\(config.domain)/pc/\(config.clientName)/sst") != nil else {
            log.error("CHEQ SST not configured, invalid domain or client")
            return
        }
        instance = Sst(config: config)
        log.info("CHEQ SST configured")
    }
    
    /// Tracks an event
    /// - Parameter event: The event to be tracked
    public static func trackEvent(_ event: Event) async {
        let _ = await _trackEvent(event)
    }
    
    /// Retrieves the stored CHEQ UUID
    public static func getCheqUuid() -> String? {
        return HTTP.getUUID()
    }
    
    /// Clears the stored CHEQ UUID
    public static func clearCheqUuid() {
        HTTP.clearUUID()
    }
    
    static func _trackEvent(_ event: Event) async -> TrackEventResult? {
        guard let instance = instance else {
            log.error("CHEQ SST not configured, must call configure first")
            return nil
        }
        if (instance.config.virtualBrowser.userAgent == nil && instance.userAgent == nil) {
            await Sst.uaTask.value
        }
        var event_data = event.data
        if !event_data.keys.contains("__timestamp") {
            let timestamp = Int(instance.config.dateProvider.now().timeIntervalSince1970 * 1000)
            event_data["__timestamp"] = timestamp
        }
        
        let screenInfo = instance.config.screenEnabled ? Info.getScreenInfo() : nil
        let sstData: [String: Any] = [
            "settings": Settings(publishPath: instance.config.publishPath, nexusHost: instance.config.nexusHost),
            "dataLayer": [
                "__mobileData": await instance.config.models.collect(event: event, sst: instance),
                instance.config.dataLayerName: dataLayer.all()
            ],
            "events": [["name": event.name, "data": event_data]],
            "virtualBrowser": VirtualBrowserData(height: screenInfo?.height,
                                                 width: screenInfo?.width,
                                                 timezone: TimeZone.current.identifier,
                                                 language: Locale.preferredLanguages.joined(separator: ","),
                                                 page: instance.config.virtualBrowser.page)
        ]
        
        let jsonString: String
        do {
            jsonString = try JSON.convertToJSONString(sstData)
        } catch {
            log.error("SerializationError: \(error, privacy: .public)")
            let _ = await Sst.sendError(msg: error.localizedDescription, fn: "Sst.trackEvent", errorName: "SerializationError")
            return nil
        }
        if let url = instance.getURL(params: event.parameters) {
            do {
                let statusCode = try await HTTP.sendHttpPost(userAgent: instance.getUA(),
                                                             url: url,
                                                             jsonString: jsonString,
                                                             debug: instance.config.debug)
                return TrackEventResult(url: url.absoluteString, requestBody: jsonString, statusCode: statusCode, userAgent: instance.getUA())
            } catch {
                log.error("NetworkError: \(error, privacy: .public)")
                let _ = await Sst.sendError(msg: error.localizedDescription, fn: "Sst.trackEvent", errorName: "NetworkError")
                return nil
            }
        } else {
            log.warning("URLComponents returned no URL for given event data")
            return nil
        }
    }
    
    static func getInstance() -> Sst {
        guard let instance = instance else {
            fatalError("CHEQ SST not configured, must call configure first")
        }
        return instance
    }
    
    static func sendError(msg: String, fn: String, errorName: String) async -> Bool {
        guard let instance = instance else {
            log.error("CHEQ SST not configured, must call configure first")
            return false
        }
        let fn = truncate(String("\(fn) \(Info.library_name):\(Info.library_version) \(Info.appInfo.name):\(Info.appInfo.version)"), 256)
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance.config.nexusHost
        components.path = "/error/e.gif"
        components.queryItems = [
            URLQueryItem(name: "msg", value: truncate(msg, 1024)),
            URLQueryItem(name: "fn", value: fn),
            URLQueryItem(name: "client", value: truncate(instance.config.clientName, 256)),
            URLQueryItem(name: "publishPath", value: truncate(instance.config.publishPath, 256)),
            URLQueryItem(name: "errorName", value: truncate(errorName, 256))
        ]
        if let url = components.url,
           let referrer = instance.getURL()?.absoluteString {
            return await HTTP.sendError(userAgent: instance.getUA(), url: url, referrer: referrer)
        } else {
            log.warning("URLComponents returned no URL for given referrer or error data")
            return false
        }
    }
    
    static func truncate(_ value: String, _ maxLength: Int) -> String {
        if value.count <= maxLength {
            return value
        } else {
            return value.prefix(maxLength - 3) + "..."
        }
    }
    
    func getParams(params:[String: String]) -> [URLQueryItem] {
        let combinedParams = params.merging(Sst.baseParams) { (_, new) in new }
        return combinedParams.keys.sorted().map { key in
            URLQueryItem(name: key, value: combinedParams[key])
        }
    }
    
    func getURL(params:[String: String] = [:]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = config.domain
        components.path = "/pc/\(config.clientName)/sst"
        components.queryItems = getParams(params: params)
        return components.url
    }
    
    func getUA() -> String? {
        return self.config.virtualBrowser.userAgent ?? self.userAgent
    }
}
