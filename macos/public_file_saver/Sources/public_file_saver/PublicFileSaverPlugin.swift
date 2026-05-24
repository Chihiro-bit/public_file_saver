import Cocoa
import FlutterMacOS

public class PublicFileSaverPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "public_file_saver",
                                           binaryMessenger: registrar.messenger)
        let instance = PublicFileSaverPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "saveBytes":
            saveBytes(call: call, result: result)
        case "saveBytesWithDialog":
            saveBytesWithDialog(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Save Bytes (Direct to Downloads)

    private func saveBytes(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytes = args["bytes"] as? FlutterStandardTypedData,
              let fileName = args["fileName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                                message: "bytes and fileName are required",
                                details: nil))
            return
        }

        let subDir = args["subDir"] as? String

        do {
            let downloadsURL = try FileManager.default.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            var targetDir = downloadsURL
            if let subDir = subDir, !subDir.isEmpty {
                targetDir = downloadsURL.appendingPathComponent(subDir)
                try FileManager.default.createDirectory(at: targetDir,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            }

            let fileURL = getUniqueFileURL(directory: targetDir, fileName: fileName)
            try bytes.data.write(to: fileURL)

            let response: [String: Any?] = [
                "fileName": fileURL.lastPathComponent,
                "uri": fileURL.absoluteString,
                "path": fileURL.path
            ]
            result(response)

        } catch {
            result(FlutterError(code: "SAVE_FAILED",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    // MARK: - Save Bytes With Dialog (NSSavePanel)

    private func saveBytesWithDialog(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytes = args["bytes"] as? FlutterStandardTypedData,
              let fileName = args["fileName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                                message: "bytes and fileName are required",
                                details: nil))
            return
        }

        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = fileName
            panel.canCreateDirectories = true

            let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow
            let completion: (NSApplication.ModalResponse) -> Void = { response in
                guard response == .OK, let url = panel.url else {
                    result(nil)
                    return
                }

                do {
                    try bytes.data.write(to: url)
                    let map: [String: Any?] = [
                        "fileName": url.lastPathComponent,
                        "uri": url.absoluteString,
                        "path": url.path
                    ]
                    result(map)
                } catch {
                    result(FlutterError(code: "SAVE_FAILED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
            }

            if let window = window {
                panel.beginSheetModal(for: window, completionHandler: completion)
            } else {
                let response = panel.runModal()
                completion(response)
            }
        }
    }

    // MARK: - Helpers

    private func getUniqueFileURL(directory: URL, fileName: String) -> URL {
        var fileURL = directory.appendingPathComponent(fileName)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension

        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            let newName = fileExtension.isEmpty
                ? "\(baseName)(\(counter))"
                : "\(baseName)(\(counter)).\(fileExtension)"
            fileURL = directory.appendingPathComponent(newName)
            counter += 1
        }

        return fileURL
    }
}
