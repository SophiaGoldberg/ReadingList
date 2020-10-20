import SwiftUI

@available(iOS 13.0, *)
struct TipNew: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("""
                Hi - I'm Andrew, the developer of this app. I hope you're finding it useful! 😊

                This app costs me time and money to develop and maintain. If you want to contribute, you can leave a tip 🙏
                """)
            if BuildInfo.thisBuild.type != .appStore {
                Text("Note: because you are testing a beta version of this app, you won't be able to leave any tips.")
            }
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

@available(iOS 13.0, *)
struct TipNew_Previews: PreviewProvider {
    static var previews: some View {
        TipNew()
    }
}
