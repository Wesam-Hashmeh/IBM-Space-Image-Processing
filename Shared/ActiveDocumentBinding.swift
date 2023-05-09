//
//  ActiveDocumentBinding.swift
//  FITSDocument
//
//  Created by Jeff Terry on 10/4/21.
//

import Foundation
import Combine
import SwiftUI

extension FocusedValues {
  struct DocumentFocusedValues: FocusedValueKey {
    typealias Value = Binding<FITSDocumentDocument>
  }

  var document: Binding<FITSDocumentDocument>? {
    get {
      self[DocumentFocusedValues.self]
    }
    set {
      self[DocumentFocusedValues.self] = newValue
    }
  }
}
