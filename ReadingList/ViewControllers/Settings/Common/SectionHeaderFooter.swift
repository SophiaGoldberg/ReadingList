import Foundation
import SwiftUI

struct HeaderText: View {
    init(_ text: String, inset: Bool) {
        self.text = text
        self.inset = inset
    }

    let text: String
    let inset: Bool

    var topPaddedText: some View {
        Text(text.uppercased()).padding(.top, 20)
    }

    var body: some View {
        if #available(iOS 14.0, *) {
            topPaddedText.padding(.horizontal, inset ? 22 : 0)
        } else {
            topPaddedText
        }
    }
}

struct FooterText: View {
    init(_ text: String, inset: Bool) {
        self.text = text
        self.inset = inset
    }

    let text: String
    let inset: Bool

    var body: some View {
        if #available(iOS 14.0, *) {
            Text(text).padding(.horizontal, inset ? 22 : 0)
        } else {
            Text(text)
        }
    }
}
