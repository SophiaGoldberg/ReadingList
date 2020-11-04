#if DEBUG
import SwiftUI
import SVProgressHUD

@available(iOS 13.0, *)
public struct DebugSettings: View {
    let showSortNumber = Binding(
        get: { Debug.showSortNumber },
        set: { Debug.showSortNumber = $0 }
    )

    private func writeToTempFile(data: [SharedBookData]) -> URL {
        let encoded = try! JSONEncoder().encode(data)
        let temporaryFilePath = URL.temporary(fileWithName: "shared_books.json")
        try! encoded.write(to: temporaryFilePath)
        return temporaryFilePath
    }

    let onDismiss: () -> Void

    @State private var currentBookDataPresented = false
    @State private var currentBookDataFile: URL?

    @State private var finishedBookDataPresented = false
    @State private var finishedBookDataFile: URL?

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Test Data"), footer: Text("Import a set of data for both testing and screenshots")) {
                    Button("Import Test Data") {
                        SVProgressHUD.show(withStatus: "Loading Data...")
                        Debug.loadData(downloadImages: true) {
                            SVProgressHUD.dismiss()
                        }
                    }
                    Button("Export Shared Data (Current Books)") {
                        currentBookDataFile = writeToTempFile(data: SharedBookData.currentBooks)
                        currentBookDataPresented = true
                    }.sheet(isPresented: $currentBookDataPresented) {
                        ActivityViewController(activityItems: [currentBookDataFile!])
                    }
                    Button("Export Shared Data (Finished Books)") {
                        finishedBookDataFile = writeToTempFile(data: SharedBookData.finishedBooks)
                        finishedBookDataPresented = true
                    }.sheet(isPresented: $finishedBookDataPresented) {
                        ActivityViewController(activityItems: [finishedBookDataFile!])
                    }
                }
                Section(header: Text("Debug Controls")) {
                    Toggle(isOn: showSortNumber) {
                        Text("Show sort number")
                    }
                }
                Section(header: Text("Error Reporting")) {
                    Button("Crash") {
                        fatalError("Test Crash")
                    }.foregroundColor(.red)
                }
            }.navigationBarTitle("Debug Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button("Dismiss") {
                onDismiss()
            })
        }
    }
}

@available(iOS 13.0, *)
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

@available(iOS 13.0, *)
struct DebugSettings_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettings { }
    }
}
#endif
