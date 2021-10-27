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

class ISOKatip: NSObject, ISOTranscriberDelegate, NSWindowDelegate {
  var transcriber: ISOTranscriber?
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
  
  @IBOutlet var preferencesMenuItem: NSMenuItem?
  @IBOutlet var preferencesPanel: NSPanel?
  @IBOutlet var preferencesLanguagesTable: NSTableView?

  @IBOutlet var progressIndicator: NSProgressIndicator?
  private var transcribedSentences: [String] = []

  private var stopTranscription: Bool = false
  private var transcriptionWasStopped: Bool = false
  
  private var lastUsedLanguage: String?
  private var audioRecordingDuration = 0.0
  private var transcriptionTimeDivider = 1.0
  private var expectedTranscriptionDuration = 0.0
  private var transcriptionStartDate: Date?
  private var haveTranscriptionDivider = false
  private var displayLocales: [Locale] = []
  var storedLocales: [String] = []

  override
  init() {
    super.init()
    transcriber = ISOTranscriber()
    transcriber?.delegate = self
    lastUsedLanguage = UserDefaults.standard.string(forKey: "LastUsedLanguage")
    let lastTranscriptionDivider = UserDefaults.standard.double(forKey: "TranscriptionTimeDivider")
    if lastTranscriptionDivider > 0.0 {
      haveTranscriptionDivider = true
      transcriptionTimeDivider = lastTranscriptionDivider
    }
    storedLocales = UserDefaults.standard.stringArray(forKey: "SelectedLanguages") ?? []
    transcriber?.setup()
  }
  
  @IBAction private func openFile(_ : Any) {
    let openPanel = NSOpenPanel()
    self.recordingFileUrl = nil
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.title = NSLocalizedString("openpanel.title", tableName: "Localization", value: "openpanel.title", comment: "")
    openPanel.prompt = NSLocalizedString("openpanel.prompt", tableName: "Localization", value: "openpanel.prompt", comment: "")
    openPanel.message = NSLocalizedString("openpanel.message", tableName: "Localization", value: "openpanel.message", comment: "")
    openPanel.allowedFileTypes = ["m4a", "mp3", "wav", "mpa"]
    if openPanel.runModal() == NSApplication.ModalResponse.OK {
      if let recordingFileUrl = openPanel.url, let mainWindow = self.mainWindow {
          let alert = NSAlert()
          alert.messageText = NSLocalizedString("transcription.info.dialog.title", tableName: "Localization", value: "transcription.info.dialog.title", comment: "")
          alert.informativeText = NSLocalizedString("transcription.info.dialog.message", tableName: "Localization", value: "transcription.info.dialog.message", comment: "")
          alert.alertStyle = NSAlert.Style.informational
          alert.beginSheetModal(for: mainWindow) { _ in
            self.transcriptionStartDate = Date()
            self.startTranscription(recordingFileUrl)
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
    progressIndicator?.startAnimation(self)
    transcribedSentences = []
    filenameField?.stringValue = url.relativePath
    stopTranscription = false
    mainWindow?.title = "Katip - " + String(format: NSLocalizedString("message.transcribing", tableName: "Localization", value: "message.transcribing", comment: ""), self.recordingFileUrl?.lastPathComponent ?? "")
    let asset = AVURLAsset(url: url, options: nil)
    let audioDuration = asset.duration
    audioRecordingDuration = CMTimeGetSeconds(audioDuration)
    expectedTranscriptionDuration = audioRecordingDuration * transcriptionTimeDivider
    progressIndicator?.isIndeterminate = !haveTranscriptionDivider
    if haveTranscriptionDivider {
      progressIndicator?.minValue = 0.0
      progressIndicator?.maxValue = expectedTranscriptionDuration
      progressIndicator?.doubleValue = 0.0
    }
    updateTranscriptionETA()
    refreshOutputTextView()
  }
  
  private func startTranscription(_ url: URL) {
    lastUsedLanguage = self.displayLocales[self.languagesPopup.indexOfSelectedItem].identifier
    if let lastUsedLanguage = lastUsedLanguage {
      UserDefaults.standard.set(lastUsedLanguage, forKey: "LastUsedLanguage")
      preferencesPanel?.orderOut(self)
      preferencesMenuItem?.isEnabled = false
      prepareTranscription(url)
      self.transcriptionStartDate = Date()
      self.transcriber?.startTranscription(url, usingLanguage: lastUsedLanguage)
    }
  }
  
  @IBAction private func stopTranscription(_ : Any) {
    stopTranscription = true
    progressETALabel?.stringValue = NSLocalizedString("message.will.stop", tableName: "Localization", value: "message.will.stop", comment: "")
    mainWindow?.title = NSLocalizedString("window.title.stopping", tableName: "Localization", value: "window.title.stopping", comment: "")
    transcriptionWasStopped = true
  }
  
  @IBAction private func retryTranscription(_ : Any) {
    if let url = self.recordingFileUrl {
      startTranscription(url)
    }
  }
  
  @IBAction private func saveTranscription(_ : Any) {
    let savePanel = NSSavePanel()
    savePanel.title = NSLocalizedString("savepanel.title", tableName: "Localization", value: "savepanel.title", comment: "")
    savePanel.prompt = NSLocalizedString("savepanel.prompt", tableName: "Localization", value: "savepanel.prompt", comment: "")
    savePanel.message = NSLocalizedString("savepanel.message", tableName: "Localization", value: "savepanel.message", comment: "")
    savePanel.nameFieldStringValue = (self.recordingFileUrl?.deletingPathExtension().lastPathComponent ?? NSLocalizedString("savepanel.untitle", tableName: "Localization", value: "savepanel.untitle", comment: "")) + ".txt"
    if let mainWindow = self.mainWindow {
      savePanel.beginSheetModal(for: mainWindow) { response in
        if response == NSApplication.ModalResponse.OK, let fileURL = savePanel.url {
          var text: String = ""
          for entry in self.transcribedSentences {
            text += entry + ".\n\n"
          }
          do {
            try text.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
          } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("saveerror.dialog.title", tableName: "Localization", value: "saveerror.dialog.title", comment: "")
            alert.informativeText = String(format: NSLocalizedString("saveerror.dialog.message", tableName: "Localization", value: "saveerror.dialog.message", comment: ""), self.recordingFileUrl?.relativePath ?? "")
            alert.alertStyle = NSAlert.Style.critical
            alert.beginSheetModal(for: mainWindow) { _ in
            }
          }
        }
      }
    }
  }
  
  private func refreshOutputTextView() {
    var text: String = ""
    for entry in transcribedSentences {
      text += entry + ".\n\n"
    }
    if text == "" {
      text = NSLocalizedString("message.waiting", tableName: "Localization", value: "message.waiting", comment: "")
    }
    outputTextView?.string = text
    if abs(self.outputTextView?.visibleRect.maxY ?? 100) - (self.outputTextView?.bounds.maxY ?? 100) < 25.0 {
      self.outputTextView?.scrollRangeToVisible(NSRange(location: text.count, length: 0))
    }
  }
  
  func updateTranscriptionETA() {
    var remainingTime = expectedTranscriptionDuration
    if let tsd = transcriptionStartDate {
      let difference = Date().timeIntervalSince(tsd)
      remainingTime -= difference
    }
    if progressIndicator?.isIndeterminate == false {
      progressIndicator?.doubleValue = expectedTranscriptionDuration - remainingTime
    }
    var eta = remainingTime
    let hours = Int((eta / 60 / 60))
    eta -= (Double(hours) * 60.0 * 60.0)
    let minutes = Int(eta / 60)
    eta -= (Double(minutes) * 60.0)
    let seconds = Int(eta)
    progressETALabel?.stringValue = String(format: NSLocalizedString("message.eta", tableName: "Localization", value: "message.eta", comment: ""), hours, minutes, seconds )
  }
  
  private func resetUI() {
    saveButton?.isEnabled = true
    retryButton?.isEnabled = true
    openButton?.isEnabled = true
    languagesPopup?.isEnabled = true
    progressIndicator?.stopAnimation(self)
    progressView?.isHidden = true
    mainWindow?.title = "Katip"
    preferencesMenuItem?.isEnabled = true
  }
  
  func updateLanguagesPopup() {
    var selectedLocaleIndex: Int =  -1
    self.languagesPopup.removeAllItems()
    var localeIndex: Int = 0
    for locale in displayLocales {
      self.languagesPopup.addItem(withTitle: localizedNameForLocale(locale))
      if lastUsedLanguage != nil, locale.identifier == lastUsedLanguage {
        selectedLocaleIndex = localeIndex
      } else if locale.identifier == Locale.current.identifier {
        selectedLocaleIndex = localeIndex
      } else if selectedLocaleIndex == -1, locale.identifier.prefix(2) == Locale.current.identifier.prefix(2) {
        selectedLocaleIndex = localeIndex
      }
      localeIndex += 1
    }
    self.languagesPopup.displayIfNeeded()
    if selectedLocaleIndex >= 0 {
      self.languagesPopup.selectItem(at: selectedLocaleIndex)
    }
  }
  
  func localizedNameForLocale(_ locale: Locale) -> String {
    if let lCode = locale.languageCode, let languageCode = locale.localizedString(forLanguageCode: lCode), let rCode = locale.regionCode, let regionCode = locale.localizedString(forRegionCode: rCode) {
      return languageCode.localizedCapitalized + " (" + regionCode + ")"
    } else if let languageCode = locale.localizedString(forIdentifier: locale.identifier) {
      return languageCode.localizedCapitalized
    } else {
      return locale.identifier
    }
  }
  
  func prepareDisplayLocales() {
    displayLocales.removeAll()
    if let transcriber = self.transcriber, transcriber.recognitionEnabled {
      for locale in transcriber.supportedLocales {
        displayLocales.append(locale)
      }
    }
    if displayLocales.count > 0, storedLocales.count > 0 {
      let localList = displayLocales
      displayLocales.removeAll()
      for locale in localList {
        if storedLocales.contains(locale.identifier) {
          displayLocales.append(locale)
        }
      }
    }
  }
  
  // MARK: Speech recognition Delegate
  func shouldStopTranscription() -> Bool {
    // We need to reset the value after returning, as we might be called twice
    // and that might create a problem in ISOTranscriber
    let retVal = stopTranscription
    stopTranscription = false
    return retVal
  }
  
  func setTranscribedText(_ text: String, withSentenceNo sentenceNo: Int) {
    updateTranscriptionETA()
    if sentenceNo == transcribedSentences.count {
      transcribedSentences.append(text)
    } else if sentenceNo < transcribedSentences.count {
      transcribedSentences[sentenceNo] = text
    }
    refreshOutputTextView()
  }
  
  func transcriptionDone() {
    resetUI()
    if transcriptionWasStopped == false {
      if let tsd = transcriptionStartDate, audioRecordingDuration > 0.0 {
        let actualTime = Date().timeIntervalSince(tsd)
        let newDividier = actualTime / audioRecordingDuration
        transcriptionTimeDivider = (transcriptionTimeDivider + newDividier) / 2
        UserDefaults.standard.setValue(transcriptionTimeDivider, forKey: "TranscriptionTimeDivider")
        transcriptionStartDate = nil
        haveTranscriptionDivider = true
      }
    }
    if let appDelegate = NSApplication.shared.delegate as? AppDelegate, appDelegate.isActive, let mainWindow = self.mainWindow {
      if transcriptionWasStopped == false {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("transcription.done.notification.title", tableName: "Localization", value: "transcription.done.notification.title", comment: "")
        alert.informativeText = String(format: NSLocalizedString("transcription.done.notification.message", tableName: "Localization", value: "transcription.done.notification.message", comment: ""), self.recordingFileUrl?.lastPathComponent ?? "")
        alert.alertStyle = NSAlert.Style.informational
        alert.beginSheetModal(for: mainWindow) { _ in
        }
      }
    } else {
      let content = UNMutableNotificationContent()
      content.title = NSLocalizedString("transcription.done.notification.title", tableName: "Localization", value: "transcription.done.notification.title", comment: "")
      content.subtitle = String(format: NSLocalizedString("transcription.done.notification.message", tableName: "Localization", value: "transcription.done.notification.message", comment: ""), self.recordingFileUrl?.lastPathComponent ?? "")
      content.sound = UNNotificationSound.default
      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request)
    }
    transcriptionWasStopped = false
  }
  
  func transcriptionCanceled() {
    resetUI()
  }
  func speechRecognitionAuthorized() {
    prepareDisplayLocales()
    updateLanguagesPopup()
  }
  
  func speechRecognitionAuthorizationFailed(_ error: String) {
  }
  
  // MARK: Preferences
  @IBAction private func showPreferences(_ : Any) {
    var selectedLanguagesSet = IndexSet()
    if let mainWindow = mainWindow, let preferencesPanel = preferencesPanel {
      preferencesLanguagesTable?.delegate = self
      preferencesLanguagesTable?.dataSource = self
      if let transcriber = self.transcriber, transcriber.recognitionEnabled {
        for i in 0..<transcriber.supportedLocales.count {
          if displayLocales.contains(transcriber.supportedLocales[i]) {
            selectedLanguagesSet.insert(i)
          }
        }
      }
      preferencesLanguagesTable?.reloadData()
      preferencesLanguagesTable?.selectRowIndexes(selectedLanguagesSet, byExtendingSelection: false)
      mainWindow.beginSheet(preferencesPanel) { _ in
      }
    }
  }
  
  @IBAction private func dismissPreferences(_ : Any) {
    if let selectedLanguages = preferencesLanguagesTable?.selectedRowIndexes, let transcriber = self.transcriber {
      storedLocales.removeAll()
      for lang in selectedLanguages {
        storedLocales.append(transcriber.supportedLocales[lang].identifier)
      }
    }
    UserDefaults.standard.set(storedLocales, forKey: "SelectedLanguages")
    if let mainWindow = mainWindow, let preferencesPanel = preferencesPanel {
      mainWindow.endSheet(preferencesPanel)
    }
    prepareDisplayLocales()
    updateLanguagesPopup()
  }
  
  @IBAction private func resetETAEstimates(_ : Any) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("reset.eta.estimates.alert.title", tableName: "Localization", value: "reset.eta.estimates.alert.title", comment: "")
    alert.informativeText = String(format: NSLocalizedString("reset.eta.estimates.message", tableName: "Localization", value: "reset.eta.estimates.message", comment: ""), self.recordingFileUrl?.relativePath ?? "")
    alert.addButton(withTitle: NSLocalizedString("reset.eta.estimates.cancel.button", tableName: "Localization", value: "reset.eta.estimates.cancel.button", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("reset.eta.estimates.reset.button", tableName: "Localization", value: "reset.eta.estimates.reset.button", comment: ""))
    alert.alertStyle = NSAlert.Style.critical
    let response = alert.runModal()
    if response == NSApplication.ModalResponse.alertSecondButtonReturn {
      UserDefaults.standard.removeObject(forKey: "TranscriptionTimeDivider")
      haveTranscriptionDivider = false
      transcriptionTimeDivider = 1.0
    }
  }
}
