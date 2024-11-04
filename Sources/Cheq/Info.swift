import Foundation
import UIKit

enum Info {
    
    static let library_name = "cheq-sst-swift"
    static let library_version = "0.2.1"
    
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
    
    static func gatherDeviceData(_ config:DeviceModelConfig) -> [String: Any] {
        let device = UIDevice.current
        
        var result: [String: Any] = [
            "manufacturer": "Apple",
            "model": appleModel,
            "architecture": cpuArchitecture
        ]
        
        if config.osEnabled {
            result["os"] = [
                "name": device.systemName,
                "version": device.systemVersion
            ]
        }
        
        if config.idEnabled {
            result["id"] = device.identifierForVendor?.uuidString ?? "Unknown"
        }
        
        if config.screenEnabled {
            result["screen"] = getScreenInfo()
        }
        
        return result
    }
    
    static func getScreenInfo() -> ScreenInfo {
        let height:Int
        let width:Int
        let orientation: String
#if os(visionOS)
        orientation = "Vision"
        // Use default values defined as 1280x720:  https://developer.apple.com/design/human-interface-guidelines/windows#visionOS:~:text=By%20default%2C%20a%20window%20measures%201280x720%20pt
        height = 720
        width = 1280
#else
        let bounds = UIScreen.main.bounds
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
        height = Int(bounds.height)
        width = Int(bounds.width)
#endif
        return ScreenInfo(orientation: orientation, height: height, width: width)
    }
}
