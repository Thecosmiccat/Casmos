import AppKit
import Foundation
import Speech
import SwiftSignalKit
import TGUIKit
import Casmos

private let casmosFrostIdentifier = NSUserInterfaceItemIdentifier("casmos.frost")

func applyCasmosFrostedWindow(_ window: NSWindow, enabled: Bool) {
    guard let content = window.contentView else {
        return
    }
    content.subviews.filter { $0.identifier == casmosFrostIdentifier }.forEach { $0.removeFromSuperview() }
    window.isOpaque = true
    window.titleVisibility = .visible
    if window.styleMask.contains(.fullSizeContentView) {
        window.styleMask.remove(.fullSizeContentView)
    }
    if enabled {
        window.titlebarAppearsTransparent = false
    }
    content.needsLayout = true
}

func casmosDeletedMessagesLogURL() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Casmos", isDirectory: true)
        .appendingPathComponent("deleted-messages.log")
}

func casmosOpenDeletedMessagesLog(window: Window) {
    let url = casmosDeletedMessagesLogURL()
    let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        showModalText(for: window, text: "No deleted messages stored. Turn on Keep Deleted Messages first.")
        return
    }
    let preview = text.split(separator: "\n").suffix(40).joined(separator: "\n")
    verifyAlert_button(for: window, header: "Deleted Messages", information: preview, ok: "Reveal Log File", cancel: strings().modalCancel, successHandler: { _ in
        NSWorkspace.shared.activateFileViewerSelecting([url])
    })
}

func casmosTranscribeAudioFile(path: String, locale: String, completion: @escaping (String?) -> Void) {
    if #available(macOS 10.15, *) {
        SFSpeechRecognizer.requestAuthorization { status in
            Queue.mainQueue().async {
                guard status == .authorized, let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else {
                    completion(nil)
                    return
                }
                recognizer.supportsOnDeviceRecognition = true
                let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
                request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
                request.shouldReportPartialResults = false
                var finished = false
                recognizer.recognitionTask(with: request) { result, error in
                    let text: String?
                    if let result, result.isFinal {
                        let value = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        text = value.isEmpty ? nil : value
                    } else if error != nil {
                        text = nil
                    } else {
                        return
                    }
                    Queue.mainQueue().async {
                        guard !finished else {
                            return
                        }
                        finished = true
                        completion(text)
                    }
                }
            }
        }
    } else {
        completion(nil)
    }
}

enum CasmosGitHubRelease {
    case unavailable
    case current
    case newer(tag: String, page: URL)
}

private func casmosReleaseTag(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count >= 2, (trimmed.first == "v" || trimmed.first == "V"), trimmed.dropFirst().first?.isNumber == true {
        return String(trimmed.dropFirst())
    }
    return trimmed
}

func casmosCheckGitHubReleases(_ completion: ((CasmosGitHubRelease) -> Void)? = nil) {
    guard let url = URL(string: "https://api.github.com/repos/Thecosmiccat/Casmos/releases/latest") else {
        completion?(.unavailable)
        return
    }
    var request = URLRequest(url: url)
    request.setValue("Casmos", forHTTPHeaderField: "User-Agent")
    URLSession.shared.dataTask(with: request) { data, response, _ in
        Queue.mainQueue().async {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 || data == nil {
                completion?(.unavailable)
                return
            }
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion?(.unavailable)
                return
            }
            let tag = (json["tag_name"] as? String) ?? ""
            let html = json["html_url"] as? String
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            if !tag.isEmpty, casmosReleaseTag(tag) != casmosReleaseTag(current), let html, let page = URL(string: html) {
                if let window = appDelegate?.window {
                    verifyAlert_button(for: window, header: "Casmos Update", information: "GitHub has \(tag). This build is \(current).", ok: "Open Release", successHandler: { _ in
                        NSWorkspace.shared.open(page)
                    })
                }
                completion?(.newer(tag: tag, page: page))
            } else {
                completion?(.current)
            }
        }
    }.resume()
}
