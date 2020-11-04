import SwiftUI

struct LinkedToAction: ViewModifier {
    let action: ProprietaryURLAction

    func body(content: Content) -> some View {
        Link(destination: ProprietaryURLManager().getURL(from: action)) {
            content
        }
    }
}

extension View {
    func actionLink(_ action: ProprietaryURLAction) -> some View {
        modifier(LinkedToAction(action: action))
    }

    func widgetURL(for action: ProprietaryURLAction) -> some View {
        widgetURL(ProprietaryURLManager().getURL(from: action))
    }
}
