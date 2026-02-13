import Flutter
import UIKit
import UniformTypeIdentifiers

public class PublicFileSaverPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {

    private var pendingResult: FlutterResult?
    private var pendingFileName: String?
    private var tempFileURL: URL?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "public_file_saver", binaryMessenger: registrar.messenger())
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

    // MARK: - Save Bytes (Direct to Documents)

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
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            var targetDir = documentsURL
            if let subDir = subDir, !subDir.isEmpty {
                targetDir = documentsURL.appendingPathComponent(subDir)
                try FileManager.default.createDirectory(at: targetDir,
                                                       withIntermediateDirectories: true,
                                                       attributes: nil)
            }

            let fileURL = getUniqueFileURL(directory: targetDir, fileName: fileName)
            try bytes.data.write(to: fileURL)

            let response: [String: Any?] = [
                "fileName": fileURL.lastPathComponent,
                "uri": nil,
                "path": fileURL.path
            ]
            result(response)

        } catch {
            result(FlutterError(code: "SAVE_FAILED",
                               message: error.localizedDescription,
                               details: nil))
        }
    }

    // MARK: - Save Bytes With Dialog

    private func saveBytesWithDialog(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytes = args["bytes"] as? FlutterStandardTypedData,
              let fileName = args["fileName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "bytes and fileName are required",
                               details: nil))
            return
        }

        // Write bytes to temp file first
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(fileName)

        do {
            try bytes.data.write(to: tempURL)
        } catch {
            result(FlutterError(code: "TEMP_FILE_FAILED",
                               message: "Failed to create temp file: \(error.localizedDescription)",
                               details: nil))
            return
        }

        self.pendingResult = result
        self.pendingFileName = fileName
        self.tempFileURL = tempURL

        DispatchQueue.main.async {
            self.presentDocumentPicker(tempURL: tempURL)
        }
    }

    private func presentDocumentPicker(tempURL: URL) {
        guard let rootVC = UIApplication.shared.delegate?.window??.rootViewController else {
            pendingResult?(FlutterError(code: "NO_VIEW_CONTROLLER",
                                        message: "Cannot find root view controller",
                                        details: nil))
            cleanupPending()
            return
        }

        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        let picker: UIDocumentPickerViewController

        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(url: tempURL, in: .exportToService)
        }

        picker.delegate = self
        picker.modalPresentationStyle = .formSheet

        presentingVC.present(picker, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate

    public func documentPicker(_ controller: UIDocumentPickerViewController,
                              didPickDocumentsAt urls: [URL]) {
        guard let result = pendingResult else {
            cleanupPending()
            return
        }

        if let url = urls.first {
            let response: [String: Any?] = [
                "fileName": url.lastPathComponent,
                "uri": url.absoluteString,
                "path": url.path
            ]
            result(response)
        } else {
            // No URL returned - use temp file info as fallback
            if let tempURL = tempFileURL {
                let response: [String: Any?] = [
                    "fileName": tempURL.lastPathComponent,
                    "uri": tempURL.absoluteString,
                    "path": tempURL.path
                ]
                result(response)
            } else {
                result(nil)
            }
        }

        cleanupPending()
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingResult?(nil)
        cleanupPending()
    }

    // MARK: - Helpers

    private func cleanupPending() {
        // Clean up temp file
        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
        }

        pendingResult = nil
        pendingFileName = nil
        tempFileURL = nil
    }

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

