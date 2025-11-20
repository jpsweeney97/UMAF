//
//  DOCXAdapter.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

//
//  DOCXAdapter.swift
//  UMAFCore
//
//  Adapter for extracting plain text from DOC, DOCX, RTF using textutil.
//

import Foundation

public enum DOCXAdapter {

  /// Extract plain text from a rich-text document using /usr/bin/textutil.
  ///
  /// This is used for:
  /// - .rtf
  /// - .doc
  /// - .docx
  ///
  /// Currently delegates to UMAFCoreEngine.Prework.extractTextWithTextUtil.
  public static func extractPlainText(usingTextUtilFrom url: URL) throws -> String {
    return try UMAFCoreEngine.Prework.extractTextWithTextUtil(from: url)
  }
}
