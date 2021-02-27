//
//  ISOKatip+NSTableViewDataSource.swift
//  Katip
//
//  Created by Imdat Solak on 27.02.21.
//

import Foundation
import AppKit

extension ISOKatip: NSTableViewDataSource {
    func numberOfRows(in: NSTableView) -> Int {
        return self.transcriber?.supportedLocales.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if let locale = self.transcriber?.supportedLocales[row] {
            return localizedNameForLocale(locale)
        } else {
            return "??"
        }
    }
}
