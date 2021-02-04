import Foundation
import SwiftUI

struct SafariViewPresenterWrapper<Wrapped>: View where Wrapped: View {
    let wrapped: Wrapped
    let url: URL
    @State var presenting = false

    var body: some View {
        wrapped
            .safariView(isPresented: $presenting) {
                SafariView(url: url)
            }
            .onTapGesture { presenting.toggle() }
    }
}

struct SafariPresentingButton<ButtonLabel>: View where ButtonLabel: View {
    let url: URL
    let buttonLabel: ButtonLabel
    let buttonAction: (() -> Void)?

    init(_ url: URL, @ViewBuilder label: () -> ButtonLabel) {
        self.url = url
        self.buttonAction = nil
        self.buttonLabel = label()
    }

    init(_ url: URL, buttonAction: @escaping () -> Void, @ViewBuilder label: () -> ButtonLabel) {
        self.url = url
        self.buttonAction = buttonAction
        self.buttonLabel = label()
    }

    @State var presenting = false

    var body: some View {
        Button(action: {
            buttonAction?()
            presenting.toggle()
        }, label: {
            buttonLabel
        }).safariView(isPresented: $presenting) {
            SafariView(url: url)
        }
    }
}

extension View {
    func presentingSafari(_ url: URL) -> some View {
        return SafariViewPresenterWrapper(wrapped: self, url: url)
    }
}
