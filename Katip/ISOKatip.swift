//
//  ISOKatip.swift
//  Katip
//
//  Created by Imdat Solak on 24.01.21.
//

import Foundation
import AppKit
import AVFoundation
import UserNotifications

class ISOKatip: NSObject, ISOTranscriberDelegate {
    private var transcriber: ISOTranscriber?
    private var recordingFileUrl: URL?
    
    @IBOutlet var mainWindow: NSWindow?
    @IBOutlet var outputTextView: NSTextView?

    @IBOutlet var languagesLabel: NSTextField?
    @IBOutlet var languagesPopup: NSPopUpButton!

    @IBOutlet var selectRecordingFileLabel: NSTextField?
    @IBOutlet var filenameField: NSTextField?
    @IBOutlet var openButton: NSButton?
    @IBOutlet var progressView: NSView?
    @IBOutlet var progressViewTitle: NSTextField?
    @IBOutlet var progressETALabel: NSTextField?
    @IBOutlet var stopButton: NSButton?
    @IBOutlet var retryButton: NSButton?
    @IBOutlet var saveButton: NSButton?

    @IBOutlet var progressIndicator: NSProgressIndicator?
    private var transcribedSentences: [String] = []

    private var stopTranscription: Bool = false
    
    override
    init() {
        super.init()
        transcriber = ISOTranscriber()
        transcriber?.delegate = self
        transcriber?.setup()
    }
    
    private func updateLanguagesPopup() {
        var selectedLocaleIndex: Int =  -1
        if let transcriber = self.transcriber, transcriber.recognitionEnabled {
            self.languagesPopup.removeAllItems()
            var localeIndex: Int = 0
            for locale in transcriber.supportedLocales {
                self.languagesPopup.addItem(withTitle: locale.identifier)
                if locale.identifier == Locale.current.identifier {
                    selectedLocaleIndex = localeIndex
                } else if selectedLocaleIndex == -1, locale.identifier.prefix(2) == Locale.current.identifier.prefix(2) {
                    selectedLocaleIndex = localeIndex
                }
                localeIndex = localeIndex + 1
            }
        }
        if selectedLocaleIndex >= 0 {
            self.languagesPopup.selectItem(at: selectedLocaleIndex)
        }
    }
    
    @IBAction
    func openFile(_ : Any) {
        let openPanel = NSOpenPanel()
        self.recordingFileUrl = nil
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = NSLocalizedString("openpanel.title", tableName: "Localization", value: "openpanel.title", comment: "")
        openPanel.prompt = NSLocalizedString("openpanel.prompt", tableName: "Localization", value: "openpanel.title", comment: "")
        openPanel.message = NSLocalizedString("openpanel.message", tableName: "Localization", value: "openpanel.title", comment: "")
        openPanel.allowedFileTypes = ["m4a", "mp3", "wav", "mpa"]
        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            if let recordingFileUrl = openPanel.url, let mainWindow = self.mainWindow {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("transcription.info.dialog.title", tableName: "Localization", value: "transcription.info.dialog.title", comment: "")
                alert.informativeText = NSLocalizedString("transcription.info.dialog.message", tableName: "Localization", value: "transcription.info.dialog.message", comment: "")
                alert.alertStyle = NSAlert.Style.informational
                alert.beginSheetModal(for: mainWindow) { response in
                    self.prepareTranscription(recordingFileUrl)
                    self.transcriber?.startTranscription(recordingFileUrl, usingLanguage: "de-DE")
                }
            }
        }
    }
    
    private func prepareTranscription(_ url: URL) {
        self.recordingFileUrl = url
        mainWindow?.makeKeyAndOrderFront(self)
        saveButton?.isEnabled = false
        retryButton?.isEnabled = false
        openButton?.isEnabled = false
        languagesPopup?.isEnabled = false
        progressView?.isHidden = false
        progressView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.80).cgColor
        progressView?.layer?.cornerRadius = 10
        progressView?.layer?.masksToBounds = true
        progressIndicator?.isIndeterminate = true
        progressIndicator?.startAnimation(self)
        transcribedSentences = []
        filenameField?.stringValue = url.relativePath
        stopTranscription = false
        mainWindow?.title = "Katip - " + String(format: NSLocalizedString("message.transcribing", tableName: "Localization", value: "message.transcribing", comment: ""), self.recordingFileUrl?.lastPathComponent ?? "")
        
        let asset = AVURLAsset(url: url, options: nil)
        let audioDuration = asset.duration
        var audioDurationSeconds = CMTimeGetSeconds(audioDuration)
        let hours = Int((audioDurationSeconds / 60 / 60))
        audioDurationSeconds = audioDurationSeconds - (Double(hours) * 60.0 * 60.0)
        let minutes = Int(audioDurationSeconds / 60)
        audioDurationSeconds = audioDurationSeconds - (Double(minutes) * 60.0)
        let seconds = Int(audioDurationSeconds)
        progressETALabel?.stringValue = String(format: "Duration: %02d:%02d:%02d", hours, minutes, seconds )

        refreshOutputTextView()
    }
    
    private func startTranscription(_ url: URL) {
        prepareTranscription(url)
        self.transcriber?.startTranscription(url, usingLanguage: "de-DE")
    }
    
    @IBAction func saveTranscription(_ : Any) {
        let savePanel = NSSavePanel()
        savePanel.title = NSLocalizedString("openpanel.title", tableName: "Localization", value: "openpanel.title", comment: "")
        savePanel.prompt = NSLocalizedString("openpanel.prompt", tableName: "Localization", value: "openpanel.title", comment: "")
        savePanel.message = NSLocalizedString("openpanel.message", tableName: "Localization", value: "openpanel.title", comment: "")
        savePanel.nameFieldStringValue = (self.recordingFileUrl?.deletingPathExtension().lastPathComponent ?? "Untitled") + ".txt"
        if let mainWindow = self.mainWindow {
            savePanel.beginSheetModal(for: mainWindow) { response in
                if response == NSApplication.ModalResponse.OK, let fileURL = savePanel.url {
                    var text: String = ""
                    for entry in self.transcribedSentences {
                        text = text + entry + ".\n\n"
                    }
                    do {
                        try text.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = NSLocalizedString("saveerror.dialog.title", tableName: "Localization", value: "saveerror.dialog.title", comment: "")
                        alert.informativeText = String(format: NSLocalizedString("saveerror.dialog.message", tableName: "Localization", value: "saveerror.dialog.message", comment: ""), self.recordingFileUrl?.relativePath ?? "")
                        alert.alertStyle = NSAlert.Style.critical
                        alert.beginSheetModal(for: mainWindow) { response in
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func stopTranscription(_ : Any) {
        stopTranscription = true
        progressETALabel?.stringValue = "Will stop..."
        mainWindow?.title = "Katip - Stopping..."
}
    
    @IBAction func retryTranscription(_ : Any) {
        if let url = self.recordingFileUrl {
            startTranscription(url)
        }
    }
    
    private func refreshOutputTextView() {
        var text: String = ""
        for entry in transcribedSentences {
            text = text + entry + ".\n\n"
        }
        if text == "" {
            text = "Waiting..."
        }
        outputTextView?.string = text
        if abs(self.outputTextView?.visibleRect.maxY ?? 100) - (self.outputTextView?.bounds.maxY ?? 100) < 25.0 {
            self.outputTextView?.scrollRangeToVisible(NSRange(location: text.count, length: 0))
        }
    }
    
    // Delegate methods
    
    func shouldStopTranscription() -> Bool {
        // We need to reset the value after returning, as we might be called twice
        // and that might create a problem in ISOTranscriber
        let retVal = stopTranscription
        stopTranscription = false
        return retVal
    }
    
    func setTranscribedText(_ text: String, withSentenceNo sentenceNo: Int) {
        if sentenceNo == transcribedSentences.count {
            transcribedSentences.append(text)
        } else if sentenceNo < transcribedSentences.count {
            transcribedSentences[sentenceNo] = text
        }
        refreshOutputTextView()
    }
    
    private func resetUI() {
        saveButton?.isEnabled = true
        retryButton?.isEnabled = true
        openButton?.isEnabled = true
        languagesPopup?.isEnabled = true
        progressIndicator?.stopAnimation(self)
        progressView?.isHidden = true
        mainWindow?.title = "Katip"
    }
    
    func transcriptionDone() {
        resetUI()
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate, appDelegate.isActive, let mainWindow = self.mainWindow {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("transcription.done.notification.title", tableName: "Localization", value: "transcription.done.notification.title", comment: "")
            alert.informativeText = String(format: NSLocalizedString("transcription.done.notification.message", tableName: "Localization", value: "transcription.done.notification.message", comment: ""), self.recordingFileUrl?.relativePath ?? "")
            alert.alertStyle = NSAlert.Style.informational
            alert.beginSheetModal(for: mainWindow) { response in
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("transcription.done.notification.title", tableName: "Localization", value: "transcription.done.notification.title", comment: "")
            content.subtitle = String(format: NSLocalizedString("transcription.done.notification.message", tableName: "Localization", value: "transcription.done.notification.message", comment: ""), self.recordingFileUrl?.relativePath ?? "")
            content.sound = UNNotificationSound.default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func transcriptionCanceled() {
        resetUI()
    }

    func speechRecognitionAuthorized() {
        updateLanguagesPopup()
    }
    
    func speechRecognitionAuthorizationFailed(_ error: String) {
    }
}
