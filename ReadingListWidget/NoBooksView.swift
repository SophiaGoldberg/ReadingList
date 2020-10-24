import SwiftUI
import WidgetKit

enum BookViewType {
    case current
    case finished
}

extension BookViewType: CustomStringConvertible {
    var description: String {
        switch self {
        case .current: return "Current"
        case .finished: return "Finished"
        }
    }
}

struct NoBooksView: View {
    let urlManager = ProprietaryURLManager()
    let type: BookViewType

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("No \(type.description) Books")
                .font(.system(.headline))
            HStack(alignment: .center, spacing: 2) {
                Text(Image(systemName: "plus.circle.fill"))
                    .offset(x: 0, y: 1)
                Text("Add Book")
                    .font(.system(.headline))
            }
            .foregroundColor(.blue)
        }
        .multilineTextAlignment(.center)
        .padding([.leading, .trailing], 8)
        .widgetURL(for: .addBookSearchOnline)
    }
}

struct NoBooksView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoBooksView(type: .finished)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            NoBooksView(type: .current)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
