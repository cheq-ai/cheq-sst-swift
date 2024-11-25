import Foundation
import os

/// A data layer that stores key-value pairs to persistent storage.
public class DataLayer : Storage {
    internal let log = Logger(subsystem: "Cheq", category: "DataLayer")
    
    init () {
        super.init(suiteName: "cheq.sst.datalayer")
    }
    
    /// returns all data present
    /// - Returns: dictionary of data, non-primitive data is returned as dictionaries
    public func all() -> [String: Any] {
        var result:[String: Any] = [:]
        if let data = data,
           let rawData = data.persistentDomain(forName: suiteName) {
            for key in rawData.keys {
                if let existing = rawData[key] as? String,
                   let jsonData = existing.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    result[key] = json["value"]
                }
            }
        }
        return result
    }
    
    /// gets value if present
    /// - Parameter key: key to retrieve
    /// - Returns: value if present, non-primitive data is returned as dictionaries
    public func get(_ key: String) -> Any? {
        var result: Any? = nil
        if let data = data,
           let rawData = data.persistentDomain(forName: suiteName),
           let existing = rawData[key] as? String,
           let jsonData = existing.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            result = json["value"]
        }
        return result
    }
    
    
    /// stores a value for the key
    /// - Parameters:
    ///   - key: key to store
    ///   - value: value to store
    public func add(key: String, value: Any) {
        do {
            let json = try JSON.convertToJSONString(["value": value])
            data?.set(json, forKey: key)
        } catch {
            log.error("Key \(key, privacy: .public), SerializationError: \(error, privacy: .public)")
            Task {
                await Sst.sendError(msg: "Key \(key), details: \(error.localizedDescription)", fn: "Sst.dataLayer.add", errorName: "SerializationError")
            }
        }
    }
}
