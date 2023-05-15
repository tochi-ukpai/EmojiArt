//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Theós on 15/05/2023.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    let document = EmojiArtDocument()
    
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}
