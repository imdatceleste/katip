//
//  AppDelegate.swift
//  Katip
//
//  Created by Imdat Solak on 24.01.21.
//

import Cocoa
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var window: NSWindow!
  var isActive: Bool = false

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
      if success {
          print("All set!")
      } else if let error = error {
          print(error.localizedDescription)
      }
    }
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    isActive = true
  }
  
  func applicationDidResignActive(_ notification: Notification) {
    isActive = false
  }
}
