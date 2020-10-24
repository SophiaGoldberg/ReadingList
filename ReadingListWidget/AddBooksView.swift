import SwiftUI
import WidgetKit

enum AddBookMode {
    case searchOnline
    case scanBarcode
    case addManually
}

extension AddBookMode {
    var imageName: String {
        switch self {
        case .searchOnline: return "text.magnifyingglass"
        case .addManually: return "doc.plaintext"
        case .scanBarcode: return "barcode.viewfinder"
        }
    }

    var text: String {
        switch self {
        case .searchOnline: return "Search\nOnline"
        case .addManually: return "Add\nManually"
        case .scanBarcode: return "Scan\nBarcode"
        }
    }

    var action: ProprietaryURLAction {
        switch self {
        case .addManually: return .addBookManually
        case .searchOnline: return .addBookSearchOnline
        case .scanBarcode: return .addBookScanBarcode
        }
    }
}

struct AddBookSingleMethodView: View {
    let mode: AddBookMode

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.imageName)
                .font(.system(size: 40))
            Text(mode.text)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }.actionLink(mode.action)
    }
}

struct AddBooksView: View {
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            AddBookSingleMethodView(mode: .scanBarcode)
            Spacer()
            AddBookSingleMethodView(mode: .searchOnline)
            Spacer()
            AddBookSingleMethodView(mode: .addManually)
            Spacer()
        }
    }
}

struct AddBooksView_Previews: PreviewProvider {
    static var previews: some View {
        AddBooksView().previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
