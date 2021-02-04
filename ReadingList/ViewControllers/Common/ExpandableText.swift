import Foundation
import SwiftUI

struct ExpandableText: View {

    /* Indicates whether the user want to see all the text or not. */
    @State private var expanded: Bool = false

    /* Indicates whether the text has been truncated in its display. */
    @State private var truncated: Bool = false

    private var text: String
    private var textStyle: Font.TextStyle
    private let lineLimit: Int

    init(_ text: String, lineLimit: Int, textStyle: Font.TextStyle = .caption) {
        self.text = text
        self.textStyle = textStyle
        self.lineLimit = lineLimit
    }

    private func determineTruncation(_ geometry: GeometryProxy) {
        // Calculate the bounding box we'd need to render the
        // text given the width from the GeometryReader.
        let total = self.text.boundingRect(
            with: CGSize(
                width: geometry.size.width,
                height: .greatestFiniteMagnitude
            ),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.preferredFont(forTextStyle: textStyle.uiFontTextStyle)],
            context: nil
        )

        if total.size.height > geometry.size.height {
            self.truncated = true
        }
    }

    func onLabelTap() {
        withAnimation {
            self.expanded = true
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // The HStack is used to ensure that the text fills the full available width, even
            // if it wouldn't normally (e.g. new line chars). We do this because we want
            // the 'see more' label to appear on the far right always.
            HStack {
                Text(self.text)
                    .font(.system(textStyle))
                    .lineLimit(self.expanded ? nil : lineLimit)
                    .background(GeometryReader { geometry in
                        Color.clear.onAppear {
                            DispatchQueue.main.async {
                                self.determineTruncation(geometry)
                            }
                        }
                    })
                    Spacer()
            }.onTapGesture(perform: onLabelTap)

            if self.truncated && !self.expanded {
                Button(action: onLabelTap) {
                    Text("show more")
                        .font(.system(textStyle))
                        .foregroundColor(Color(.systemBlue))
                }.background(Color(.systemBackground))
                .padding(.leading, 80)
                .background(
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(
                                stops: [
                                    .init(color: Color(.systemBackground).opacity(0), location: 0),
                                    .init(color: Color(.systemBackground), location: 60 / geometry.size.width),
                                    .init(color: Color(.systemBackground), location: 1)
                                ]
                            ),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                )
            }
        }
    }
}

extension Font.TextStyle {
    var uiFontTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

struct ExpandableText_Previews: PreviewProvider {
    static var previews: some View {
        ExpandableText("Size classes are a great way to make your user interfaces intelligently adapt to the available space by using a VStack or a HStack for your content. For example, if you have lots of space you might lay things out horizontally, but switch to vertical layout when space is limited. ", lineLimit: 2)
            .padding()
    }
}
