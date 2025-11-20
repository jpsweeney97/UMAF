//
//  UMAFError.swift
//  Part of UMAFCore — user-facing error taxonomy
//

import Foundation

public enum UMAFUserError: Error, Equatable {
    case badUTF8
    case unsupportedMediaType(String)   // e.g. "application/pdf"
    case schemaMismatch(String)         // human-readable reason
    case invalidJSON(String)            // parse error
    case invalidMarkdown(String)        // parse error
    case ioError(String)                // reading/writing issues
    case internalError(String)          // fallback for unexpected problems
}

extension UMAFUserError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .badUTF8:
            return "The input contains bytes that are not valid UTF‑8."
        case .unsupportedMediaType(let mt):
            return "Unsupported media type: \(mt)."
        case .schemaMismatch(let why):
            return "Envelope didn't match the UMAF schema: \(why)"
        case .invalidJSON(let why):
            return "Invalid JSON: \(why)"
        case .invalidMarkdown(let why):
            return "Invalid Markdown: \(why)"
        case .ioError(let why):
            return "I/O error: \(why)"
        case .internalError(let why):
            return "Unexpected internal error: \(why)"
        }
    }

    /// Short, actionable message for CLI/app output.
    public var userMessage: String {
        switch self {
        case .badUTF8:
            return "Input isn’t valid UTF‑8. Convert the file to UTF‑8 and retry."
        case .unsupportedMediaType:
            return "This file type isn’t supported yet. Try .txt, .md or .json."
        case .schemaMismatch:
            return "Output failed schema validation. Please file a bug with the failing file."
        case .invalidJSON:
            return "Couldn’t parse JSON. Check for trailing commas or mismatched braces."
        case .invalidMarkdown:
            return "Markdown parse failed. Check code fences and table formatting."
        case .ioError:
            return "Couldn’t read or write the file. Check the path and permissions."
        case .internalError:
            return "Something went wrong. Try again or report this with the repro file."
        }
    }

    /// Stable exit codes for CLI integration/automation.
    public var exitCode: Int32 {
        switch self {
        case .badUTF8: return 10
        case .unsupportedMediaType: return 11
        case .schemaMismatch: return 12
        case .invalidJSON: return 13
        case .invalidMarkdown: return 14
        case .ioError: return 15
        case .internalError: return 20
        }
    }
}

/// Convenience wrapper to box any thrown error into UMAFUserError
public func asUMAFUserError(_ error: Error) -> UMAFUserError {
    if let e = error as? UMAFUserError { return e }
    // Try to infer some common errors
    let ns = error as NSError
    if ns.domain == NSCocoaErrorDomain {
        return .ioError(ns.localizedDescription)
    }
    // Fallback
    return .internalError(ns.localizedDescription)
}
