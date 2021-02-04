import Foundation
import SwiftUI

extension View {
    func navigating<Destination>(to destination: Destination) -> some View where Destination: View {
        return NavigationLink(destination: destination) {
            self
        }
    }
}
