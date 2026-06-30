//
//  JSONDocument.swift
//  MemoryEcho
//
//  A trivial FileDocument wrapper so SwiftUI's `.fileExporter` can write the
//  backup JSON `Data` straight to a file the user picks (Files / iCloud Drive).
//  Import reads its bytes back as raw `Data` for BackupService to decode.
//

import SwiftUI
import UniformTypeIdentifiers

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
