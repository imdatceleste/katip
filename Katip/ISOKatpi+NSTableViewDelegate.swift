//
//  ISOKatpi+NSTableViewDelegate.swift
//  Katip
//
//  Created by Imdat Solak on 27.02.21.
//

import Foundation
import AppKit

extension ISOKatip: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        false
    }
    
    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let selectedLanguages = preferencesLanguagesTable?.selectedRowIndexes, let transcriber = self.transcriber {
            storedLocales.removeAll()
            for lang in selectedLanguages {
                storedLocales.append(transcriber.supportedLocales[lang].identifier)
            }
        }
        UserDefaults.standard.set(storedLocales, forKey: "SelectedLanguages")
        prepareDisplayLocales()
        updateLanguagesPopup()
    }
}
