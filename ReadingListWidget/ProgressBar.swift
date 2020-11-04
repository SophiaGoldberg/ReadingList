import Foundation
import SwiftUI

struct ProgressBar: View {
    let currentProgress: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geometryProxy in
                RoundedRectangle(cornerRadius: 1)
                    .foregroundColor(Color(.tertiarySystemFill))
                    .frame(width: geometryProxy.size.width, height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .foregroundColor(.blue)
                    .frame(width: geometryProxy.size.width * min(max(currentProgress, 0), 1), height: 2)
            }
        }
    }
}
