import Foundation
import SwiftUI

extension View {
    func possiblyInsetGroupedListStyle(inset: Bool) -> some View {
        PossiblyInsetGroupedListStyle(inset: inset, contents: self)
    }
}

struct PossiblyInsetGroupedListStyle<V>: View where V: View {
    let inset: Bool
    let contents: V

    var paddedBody: some View {
        contents.padding(.top, 0).background(Color(.systemGroupedBackground))
    }

    var body: some View {
        if #available(iOS 14.0, *), inset {
            paddedBody.listStyle(InsetGroupedListStyle())
        } else {
            paddedBody.listStyle(GroupedListStyle())
        }
    }
}
