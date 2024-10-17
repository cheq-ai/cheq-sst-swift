import Foundation
import UIKit

enum Info {
    
    static let library_name = "cheq-sst-swift"
    static let library_version = "0.1.1"
    
    static var cpuArchitecture: String = {
#if arch(x86_64)
        return "x86_64"
#elseif arch(arm64)
        return "arm64"
#else
        return "Unknown"
#endif
    }()
    
    static var appInfo: AppInfo = {
        if let infoDict = Bundle.main.infoDictionary {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown"
            let namespace = bundleIdentifier.components(separatedBy: ".").first ?? bundleIdentifier
            return AppInfo(namespace: namespace,
                           name: infoDict["CFBundleName"] as? String ?? "Unknown",
                           version: infoDict["CFBundleShortVersionString"] as? String ?? "Unknown",
                           build: infoDict["CFBundleVersion"] as? String ?? "Unknown")
        }
        return AppInfo(namespace: "Unknown", name: "Unknown", version: "Unknown", build: "Unknown")
    }()
    
    static var appleModel: String = {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        } else {
            var systemInfo = utsname()
            uname(&systemInfo)
            
            let modelCode = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    ptr in String(cString: ptr)
                }
            }
            
            return modelCode
        }
    }()
    
    static func gatherDeviceData() -> [String: Any] {
        let device = UIDevice.current
        
        return [
            "manufacturer": "Apple",
            "os": [
                "name": device.systemName,
                "version": device.systemVersion
            ],
            "model": appleModel,
            "id": device.identifierForVendor?.uuidString ?? "Unknown",
            "screen": getScreenInfo(),
            "architecture": cpuArchitecture
        ]
    }
    
    static func getScreenInfo() -> ScreenInfo {
#if os(visionOS)
        return ScreenInfo(orientation: "Vision", height: 0, width: 0)
#else
        let bounds = UIScreen.main.bounds
        let orientation: String
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = "Portrait"
        case .faceDown:
            orientation = "Face Down"
        case .faceUp:
            orientation = "Face Up"
        case .landscapeLeft:
            orientation = "Landscape Left"
        case .landscapeRight:
            orientation = "Landscape Right"
        case .portraitUpsideDown:
            orientation = "Portrait Upside Down"
        case .unknown:
            orientation = "Unknown"
        @unknown default:
            orientation = "Unknown"
        }
        return ScreenInfo(orientation: orientation, height: Int(bounds.height), width: Int(bounds.width))
#endif
    }
}
