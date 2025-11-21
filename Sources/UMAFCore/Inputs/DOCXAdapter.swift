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
  public static func extractPlainText(usingTextUtilFrom url: URL) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
    process.arguments = ["-convert", "txt", "-stdout", url.path]

    let out = Pipe()
    let err = Pipe()
    process.standardOutput = out
    process.standardError = err

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      throw NSError(
        domain: "UMAF", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "textutil failed: \(msg)"])
    }

    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
  }
}
