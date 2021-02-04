import Foundation
import UIKit
import SwiftUI

/** Wraps UIActivityIndicator, which is not available in SwiftUI in iOS 13.
 */
struct ProgressSpinnerView: UIViewRepresentable {

    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: UIViewRepresentableContext<ProgressSpinnerView>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ProgressSpinnerView>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
