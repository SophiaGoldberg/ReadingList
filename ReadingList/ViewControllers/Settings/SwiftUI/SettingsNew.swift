import SwiftUI

@available(iOS 13.0, *)
struct SettingsNew: View {
    let writeReviewUrl = URL(string: "itms-apps://\(Settings.appStoreAddress)?action=write-review")!
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SettingsHeader()
                }.listRowBackground(Color(.groupTableViewBackground))
                Section {
                    SettingsCell("About", imageName: "info", color: .blue)
                        .navigating(to: AboutNew())
                    SettingsCell("Rate", imageName: "star.fill", color: .orange)
                        .buttonWithTap {
                            UIApplication.shared.open(writeReviewUrl, options: [:])
                        }
                    SettingsCell("Leave Tip", imageName: "heart.fill", color: .pink)
                        .navigating(to: TipNew())
                }
                Section {
                    SettingsCell("General", imageName: "gearshape.fill", color: .gray)
                        .navigating(to: GeneralNew())
                    SettingsCell("Sort", imageName: "chevron.up.chevron.down", color: .blue)
                    SettingsCell("Import / Export", imageName: "doc.fill", color: .green)
                }
            }.navigationBarTitle("Settings", displayMode: .inline)
        }.navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
}

@available(iOS 13.0, *)
struct SettingsHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            Image("AppIconOnWhiteRounded")
                .resizable()
                .frame(width: 80, height: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text("Reading List").fontWeight(.semibold)
                    Text("v\(BuildInfo.thisBuild.versionAndConfiguration)").font(.system(size: 12))
                }
                Text("by Andrew Bennet").font(.footnote)
            }
        }
    }
}

@available(iOS 13.0, *)
struct SettingsNew_Previews: PreviewProvider {
    static var previews: some View {
        SettingsNew()
    }
}
