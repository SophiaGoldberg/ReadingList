import Foundation
import SwiftUI

struct ProgressDisplay: View {
    let progressPercentage: Int

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            ProgressBar(currentProgress: CGFloat(Double(progressPercentage) / 100))
                .padding([.leading, .trailing], 8)
                .frame(height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(progressPercentage)%")
                .font(.system(size: 10))
                .foregroundColor(Color(.secondaryLabel))
                .fontWeight(.medium)
        }
    }
}
