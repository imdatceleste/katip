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
}
