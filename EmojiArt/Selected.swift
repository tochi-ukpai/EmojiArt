//
//  Selected.swift
//  EmojiArt
//
//  Created by Theós on 16/05/2023.
//

import SwiftUI

struct Selected: ViewModifier {
    var isSelected: Bool
    var action: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            if isSelected {
                Rectangle()
                    .strokeBorder(lineWidth: 1)
                    .foregroundColor(.accentColor)
                    .scaledToFit()
                    .overlay(
                        GeometryReader { geometry in
                            Button(action: action) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.red)
                            }
                            .position(x: geometry.size.width, y: geometry.size.height)
                        }
                    )
                    .rotationEffect(Angle.degrees(-90))
            }
            content
        }
        .fixedSize()
    }
}


extension View {
    func selected(_ isSelected: Bool, action: @escaping () -> Void) -> some View {
        self.modifier(Selected(isSelected: isSelected, action: action))
    }
}
