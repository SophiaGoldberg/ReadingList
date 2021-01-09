import Foundation
import SwiftUI

struct ReadingListPro: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
        VStack(spacing: 32) {
            Text("Reading List Pro")
                .font(.system(.title))
                .fontWeight(.semibold)
                //.padding(.bottom)
            Text("""
                Reading List Pro is an optional extension to Reading List, which enables some additional features for a monthly fee.
                """).font(.body)
            //ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    Feature(
                        systemImageName: "icloud.fill",
                        title: "iCloud Sync",
                        summary: "Realtime synchronisation between all your devices via iCloud."
                    )
                    Feature(
                        systemImageName: "network",
                        title: "URL Scheme",
                        summary: "Access to a custom URL scheme and set of URL endpoints to manage your books."
                    )
//                    Feature(
//                        systemImageName: "apps.ipad",
//                        title: "App Icons",
//                        summary: "Choose alternative app icons to use on the homescreen."
//                    )
                    Feature(
                        systemImageName: "heart",
                        title: "Support Development",
                        summary: "Supports the maintenance and  development of features."
                    )
                    
                }.padding([.leading, .trailing], 20)
            //}.frame(maxHeight: .infinity)
            Text("The core features of Reading List will always be free without limits, and the app will never nag you to join Pro.")
            HStack(alignment: .center, spacing: 32) {
                Button(action: {}) {
                    BlockColorButton(text: "£2.99\nMonthly")
                }
                Button(action: {}) {
                    BlockColorButton(text: "£14.99\nYearly")
                }
            }
            NavigationLink(
                destination: ReadingListProFaq()
            ) {
                Text("Read More")
            }
            Spacer()
        }.padding([.top, .bottom], 20)
        .padding([.leading, .trailing], 8)
        }
    }
}

struct BlockColorButton: View {
    let text: String
    var body: some View {
        Text(text)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(6)
            .padding([.leading, .trailing], 6)
            .background(Color(.systemBlue))
            .cornerRadius(8)
    }
}

struct Feature: View {
    let systemImageName: String
    let title: String
    let summary: String
    
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImageName)
                .font(.system(size: 36))
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
            Text(summary)
                .font(.footnote)
                .foregroundColor(.secondary)
        }.frame(maxWidth: 200)
    }
}

struct ReadingListPro_Previews: PreviewProvider {
    static var previews: some View {
        ReadingListPro()
    }
}
