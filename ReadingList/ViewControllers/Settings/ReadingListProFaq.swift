import Foundation
import SwiftUI

struct ReadingListProFaq: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text("Reading List Pro\nMore Info")
                .fontWeight(.bold)
                .font(.title)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                FaqEntry("What is Reading List Pro?") {
                    Text("Reading List Pro is an optional add-on to Reading List, which unlocks some of the more advanced or niche features in exchange for a month subscription.")
                }
                Group {
                    Text("What is Reading List Pro?").font(.headline)
                    Text("Reading List Pro is an optional add-on to Reading List, which unlocks some of the more advanced or niche features in exchange for a month subscription.").padding(.bottom, 8)

                    Text("Why do I need to pay?").font(.headline)
                    Text("Reading List is developed by me, Andrew, a solo developer, and was first released in 2017. Developing an app costs money: licence fees, artwork costs, test devices, learning materials, but most of all: time. I've devoted hundreds of hours to developing Reading List for use by all readers who want to use it, for free. To ensure I can continue to develop Reading List, I'm starting to charge for some of the advanced features. Everything released between 2017 and January 2021 will remain free of charge.").padding(.bottom, 8)

                    Text("What features are paid?").font(.headline)
                    Text("""
                        Broadly, newer features which are likely to be predominantly used by advanced / heavy users of the app, but which are not essential for most users. In the initial release, this includes:
                          • iCloud sync, for users with multiple devices (iPhone & iPad, for example)
                          • URL scheme tools to connect the app to external workflows such as Shortcuts
                          • Custom app icon options
                        """).padding(.bottom, 8)

                    Text("Is my data at risk without iCloud sync?").font(.headline)
                    Text("No. I never want to put users data at risk, pro or otherwise. Non-Pro users still benefit from the iCloud Backup functionality, which can automatically back up a user's database every night.").padding(.bottom, 8)

                }
                Group {
                    Text("How do I cancel?").font(.headline)
                    Text("You can cancel at any time either from within the app, or from the Settings app.").padding(.bottom, 8)

                    Text("Can I share my subscription?").font(.headline)
                    Text("Yes! I've enabled family sharing for this subscription, so it can be shared with others in your iCloud \"family\".").padding(.bottom, 8)
                }
            }.padding([.leading, .trailing], 16)
        }
    }
}

struct FaqEntry<Body>: View where Body: View {
    let title: String
    let content: Body
    
    init(_ title: String, @ViewBuilder content: () -> Body) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        Group {
            Text(title).font(.headline)
            content
        }.padding(.bottom, 8)
    }
}


struct ReadingListProFaqPreviewProvider: PreviewProvider {
    static var previews: some View {
        ReadingListProFaq()
    }
}
