//
//  ISOTranscriber.swift
//  Katip
//
//  Created by Imdat Solak on 24.01.21.
//

import Foundation
import AVFoundation
import Accelerate
import Speech

protocol ISOTranscriberDelegate: AnyObject {
  func setTranscribedText(_ text: String, withSentenceNo sentenceNo: Int)
  func shouldStopTranscription() -> Bool
  func transcriptionDone()
  func transcriptionCanceled()
  func speechRecognitionAuthorized()
  func speechRecognitionAuthorizationFailed(_ error: String)
}

class ISOTranscriber: NSObject {
  var delegate: ISOTranscriberDelegate?
  private var recognizer: SFSpeechRecognizer!
  private var recognitionTask: SFSpeechRecognitionTask!
  private var currentSentenceNo: Int = 0
  private var previousResult: SFSpeechRecognitionResult?

  var supportedLocales: [Locale] = []
  var recognitionEnabled: Bool = false
  
  override
  init() {
    super.init()
    var availableLocales = Array(SFSpeechRecognizer.supportedLocales())
    availableLocales.sort {
      $0.identifier < $1.identifier
    }
    for locale in availableLocales {
      if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition {
        self.supportedLocales.append(locale)
      }
    }
  }

  func setup() {
    SFSpeechRecognizer.requestAuthorization { authStatus in
      OperationQueue.main.addOperation {
        switch authStatus {
          case .authorized:
            self.recognitionEnabled = true
            self.delegate?.speechRecognitionAuthorized()
          case .denied:
            self.recognitionEnabled = false
            self.delegate?.speechRecognitionAuthorizationFailed("errormessage.speech.denied")
          case .restricted:
            self.recognitionEnabled = false
            self.delegate?.speechRecognitionAuthorizationFailed("errormessage.speech.restricted")
          case .notDetermined:
            self.recognitionEnabled = false
            self.delegate?.speechRecognitionAuthorizationFailed("errormessage.speech.not_determined")
          @unknown default:
            self.delegate?.speechRecognitionAuthorizationFailed("errormessage.speech.unknown")
        }
      }
    }
  }
 
  func startTranscription(_ recordingFileUrl: URL, usingLanguage language: String) {
    guard self.recognitionEnabled == true else { return }
    guard self.supportedLocales.count > 0 else { return }
    self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
    self.previousResult = nil
    let recognitionRequest = SFSpeechURLRecognitionRequest(url: recordingFileUrl)
    recognitionRequest.requiresOnDeviceRecognition = true
    recognitionRequest.shouldReportPartialResults = true
    recognitionRequest.taskHint = SFSpeechRecognitionTaskHint.dictation
    self.currentSentenceNo = 0
    self.recognitionTask = self.recognizer.recognitionTask(with: recognitionRequest, delegate: self)
  }
}

extension ISOTranscriber: SFSpeechRecognitionTaskDelegate {
  func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
    NSLog("Detected Speech")
  }
  
  func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
    NSLog("speechRecognitionTaskFinishedReadingAudio")
  }
  
  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
    self.delegate?.setTranscribedText(transcription.formattedString, withSentenceNo: self.currentSentenceNo)
    if self.delegate?.shouldStopTranscription() ?? false {
      self.recognitionTask.cancel()
      self.recognitionTask = nil
    }
  }

  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
    self.delegate?.setTranscribedText(recognitionResult.bestTranscription.formattedString, withSentenceNo: self.currentSentenceNo)
    self.currentSentenceNo += 1
    if self.delegate?.shouldStopTranscription() ?? false {
      self.recognitionTask.cancel()
      self.recognitionTask = nil
    }
  }

  func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
    NSLog("DidFinishSuccessfully")
    self.recognitionTask = nil
    self.delegate?.transcriptionDone()
  }

  func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
    NSLog("Cancelled")
    self.recognitionTask = nil
    self.delegate?.transcriptionCanceled()
  }
}
