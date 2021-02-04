import Foundation
import SwiftUI

struct SelectionForm<Selection>: View where Selection: CustomStringConvertible, Selection: Equatable, Selection: Identifiable {
    let options: [Selection]
    @Binding var selectedOption: Selection

    var body: some View {
        Form {
            ForEach(options) { option in
                HStack {
                    Text(option.description)
                    Spacer()
                    if option == selectedOption {
                        Image(systemName: "checkmark").foregroundColor(Color(.systemBlue))
                    }
                }.contentShape(Rectangle())
                .onTapGesture {
                    selectedOption = option
                }
            }
        }
    }
}
