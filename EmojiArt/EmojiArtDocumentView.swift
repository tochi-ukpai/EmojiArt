//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Theós on 15/05/2023.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    @State var selectedEmojis = Set<EmojiArtModel.Emoji>()
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0, 0), in: geometry))
                )
                .gesture(doubeTapToZoom(in: geometry.size))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView()
                        .scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        emojiView(for: emoji, in: geometry)
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture()
                .simultaneously(with: zoomGesture())
                .simultaneously(with: tapToUnselectAll())
            )
        }
    }
    
    @ViewBuilder
    private func emojiView(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> some View {
        let isSelected = selectedEmojis.contains(matching: emoji)
        let emojiView = Text(emoji.text)
            .font(.system(size: fontSize(for: emoji, isSelected: isSelected)))
            .selected(isSelected, action: {
                removeEmoji(emoji)
            })
            .scaleEffect(zoomScale)
            .position(position(for: emoji, in: geometry))
            .gesture(tapToSelect(emoji))
        
        if isSelected {
            emojiView
                .offset(gestureMoveOffset)
                .gesture(dragToMoveGesture())
        } else {
            emojiView
        }
    }
    
    private func removeEmoji(_ emoji: EmojiArtModel.Emoji) {
        document.removeEmoji(emoji)
        selectedEmojis.toggleMembership(of: emoji)
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        
        return found
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji, isSelected: Bool) -> CGFloat {
        if isSelected {
            return (CGFloat(emoji.size) * resizeScale).rounded(.toNearestOrAwayFromZero)
        } else {
            return CGFloat(emoji.size)
        }
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    private func tapToUnselectAll() -> some Gesture {
        TapGesture()
            .onEnded {
                selectedEmojis.removeAll()
            }
    }
    
    private func tapToSelect(_ emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture()
            .onEnded {
                selectedEmojis.toggleMembership(of: emoji)
            }
    }
    
    
    @GestureState private var gestureMoveOffset: CGSize = CGSize.zero
    
    private var moveOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func dragToMoveGesture() -> some Gesture {
        DragGesture()
            .updating($gestureMoveOffset) { latestDragMoveValue, gestureMoveOffset, _ in
                gestureMoveOffset = latestDragMoveValue.translation
            }
            .onEnded { finalDragMoveValue in
                moveEmojis(by: finalDragMoveValue.translation / zoomScale)
            }
    }
    
    private func moveEmojis(by distance: CGSize) {
        selectedEmojis.forEach { emoji in
            document.moveEmoji(emoji, by: distance)
        }
    }
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    @GestureState private var gestureResizeScale: CGFloat = 0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private var resizeScale: CGFloat {
        1 + gestureResizeScale // 1 indicates current emoji size
    }
    
    private func zoomGesture() -> some Gesture {
        return MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                if selectedEmojis.isEmpty {
                    gestureZoomScale = latestGestureScale
                }
            }
            .updating($gestureResizeScale) { latestGestureScale, gestureResizeScale, _ in
                if !selectedEmojis.isEmpty && latestGestureScale <= 1 {
                    gestureResizeScale = latestGestureScale
                }
            }
            .onEnded { gestureScaleAtEnd in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                } else if !selectedEmojis.isEmpty {
                    let offset = gestureScaleAtEnd < 1 ? gestureScaleAtEnd : 1
                    resizeSelectedEmojis(by: offset)
                }
            }
    }
    
    private func resizeSelectedEmojis(by scale: CGFloat) {
        selectedEmojis.forEach { emoji in
            document.scaleEmoji(emoji, by: scale)
        }
    }
    
    private func doubeTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    
    let testEmojis = "😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
    
}


struct ScrollingEmojisView: View {
    let emojis: String
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                    
                }
            }
        }
    }
}













struct EmojiArtDocument_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
