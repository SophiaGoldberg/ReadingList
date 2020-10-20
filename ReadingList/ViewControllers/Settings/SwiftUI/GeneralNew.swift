import SwiftUI

@available(iOS 13.0, *)
struct GeneralNew: View {
    var body: some View {
        Form {
            Section(header: Text("Appearance"), footer: Text("Enable Expanded Descriptions to automatically show each book's full description.")) {
                Toggle(isOn: .constant(true), label: {
                    Text("Expanded Descriptions")
                })
            }
            Section(header: Text("Progress"), footer: Text("Choose whether to default to Page Number or Percentage when setting progress.")) {
                NavigationLink(destination: Text("Destination")) {
                    HStack {
                        Text("Default Progress Type")
                        Spacer()
                        Text("Page").foregroundColor(.secondary)
                    }
                }
            }
            Section(header: Text("Language"), footer: Text("""
                By default, Reading List prioritises search results based on their language and your location. To instead \
                restrict search results to be of a specific language only, select a language above.
                """)) {
                Toggle(isOn: .constant(true), label: {
                    Text("Remember Last Selection")
                })
                HStack {
                    Text("Restrict Search Results")
                    Spacer()
                    Text("None").foregroundColor(.secondary)
                }
            }
            Section(header: Text("Analytics"), footer: Text("""
                Crash reports can be automatically sent to help me detect and fix issues. Analytics can \
                be used to help gather usage statistics for different features. This never includes any \
                details of your books.\
                \(BuildInfo.thisBuild.type != .testFlight ? "" : " If Beta testing, these cannot be disabled.")
                """)) {
                Toggle(isOn: .constant(true), label: {
                    Text("Send Crash Reports")
                })
                Toggle(isOn: .constant(true), label: {
                    Text("Send Analytics")
                })
            }
        }.navigationBarTitle("General", displayMode: .inline)
    }
}

@available(iOS 13.0, *)
struct GeneralNew_Previews: PreviewProvider {
    static var previews: some View {
        GeneralNew()
    }
}
