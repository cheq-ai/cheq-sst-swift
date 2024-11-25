import Foundation

/// Persistent key-value storage.
public class Storage {
    internal let suiteName: String
    let data: UserDefaults?
    
    internal init(suiteName: String) {
        self.suiteName = suiteName
        self.data = UserDefaults(suiteName: suiteName)
    }
    
    /// clears all values
    public func clear() {
        data?.removePersistentDomain(forName: suiteName)
    }
    
    /// checks if key is present
    /// - Parameter key: key to check
    /// - Returns: true if key exists
    public func contains(_ key:String) -> Bool {
        return data?.persistentDomain(forName: suiteName)?.index(forKey: key) != nil
    }
    
    /// removes a key if present
    /// - Parameter key: key to remove
    /// - Returns: true if key exists and was removed
    public func remove(_ key: String) -> Bool {
        guard contains(key) else {
            return false
        }
        data?.removeObject(forKey: key)
        return true
    }
}

/// SST Storage, supports string keys and string values only.
public class SstStorage : Storage {
    internal let keyName: String
    
    internal init(suiteName: String, keyName: String) {
        self.keyName = keyName
        super.init(suiteName: suiteName)
    }
    
    /// stores a value for the key
    /// - Parameters:
    ///   - key: key to store
    ///   - value: value to store
    public func add(key: String, value: String) {
        data?.set(value, forKey: key)
    }
    
    /// returns all data present
    /// - Returns: dictionary of data
    public func all() -> [String: String] {
        var result:[String: String] = [:]
        if let data = data,
           let rawData = data.persistentDomain(forName: suiteName) {
            for key in rawData.keys {
                if let existing = rawData[key] as? String {
                    result[key] = existing
                }
            }
        }
        return result
    }
    
    /// gets value if present
    /// - Parameter key: key to retrieve
    /// - Returns: value if present
    public func get(_ key: String) -> String? {
        var result: String? = nil
        if let data = data,
           let rawData = data.persistentDomain(forName: suiteName),
           let existing = rawData[key] as? String {
            result = existing
        }
        return result
    }
    
    internal func eventData() -> [[String: String]]? {
        var result: [[String: String]]? = nil
        let data = self.all()
        if !data.isEmpty {
            result = data.map { entry in
                [
                    keyName: entry.key,
                    "value": entry.value
                ]
            }
        }
        return result
    }
}

/// SST cookies.
public class Cookies : SstStorage {
    internal init () {
        super.init(suiteName: "cheq.sst.storage.cookie", keyName: "name")
    }
}

/// SST localStorage.
public class LocalStorage : SstStorage {
    internal init () {
        super.init(suiteName: "cheq.sst.storage.local", keyName: "key")
    }
}

/// SST sessionStorage.
public class SessionStorage : SstStorage {
    internal init () {
        super.init(suiteName: "cheq.sst.storage.session", keyName: "key")
    }
}
