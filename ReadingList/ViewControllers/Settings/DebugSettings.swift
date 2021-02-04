#if DEBUG
import SwiftUI
import SVProgressHUD

public struct DebugSettings: View {

    // FUTURE: Use some proper SwiftUI stuff for these: ObservableObject, or AppStorage?
    let showSortNumber = Binding(
        get: { Debug.showSortNumber },
        set: { Debug.showSortNumber = $0 }
    )

    let stayOnBackupRestorationDownloadScreen = Binding(
        get: { Debug.stayOnBackupRestorationDownloadScreen },
        set: { Debug.stayOnBackupRestorationDownloadScreen = $0 }
    )

    let simulateBackupFailed = Binding(
        get: { Debug.simulateBackupFailure },
        set: { Debug.simulateBackupFailure = $0 }
    )

    private func writeToTempFile(data: [SharedBookData]) -> URL {
        let encoded = try! JSONEncoder().encode(data)
        let temporaryFilePath = URL.temporary(fileWithName: "shared_books.json")
        try! encoded.write(to: temporaryFilePath)
        return temporaryFilePath
    }

    @Binding var isPresented: Bool

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
                    Toggle(isOn: stayOnBackupRestorationDownloadScreen) {
                        Text("Spoof long backup download")
                    }
                }

                Section(header: Text("Backup")) {
                    Button("Schedule Backup") {
                        AutoBackupManager.shared.lastBackupCompletion = nil
                        AutoBackupManager.shared.scheduleBackup()
                    }
                    if let lastBackup =
                        AutoBackupManager.shared.lastBackupCompletion {
                        HStack {
                            Text("Last Backup")
                            Spacer()
                            Text(lastBackup.formatted(dateStyle: .medium, timeStyle: .short))
                            if AutoBackupManager.shared.lastAutoBackupFailed {
                                Text("(Failed)")
                            }
                        }
                    }
                    if let nextBackupStart =
                        AutoBackupManager.shared.nextBackupEarliestStartDate {
                        HStack {
                            Text("Next Backup")
                            Spacer()
                            Text(nextBackupStart.formatted(dateStyle: .medium, timeStyle: .short))
                        }
                    }
                }
                Section(header: Text("Error Reporting")) {
                    Toggle(isOn: simulateBackupFailed) {
                        Text("Simulate Failed Backup")
                    }
                    Button("Crash") {
                        fatalError("Test Crash")
                    }.foregroundColor(.red)
                }
                    Section(header: Text("iCloud Sync")) {
                        Button("Simulate remote change notification") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if GeneralSettings.iCloudSyncEnabled, let syncCoordinator = AppDelegate.shared.syncCoordinator as? SyncCoordinator/*, syncCoordinator.remote.isInitialised */{
                                    syncCoordinator.respondToRemoteChangeNotification()
                                }
                            }
                        }.disabled(
                            !GeneralSettings.iCloudSyncEnabled//TODO || (AppDelegate.shared.syncCoordinator as? SyncCoordinator)?.remote.isInitialised != true
                        )
                    }
            }.navigationBarTitle("Debug Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button("Dismiss") {
                isPresented = false
            })
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct DebugSettings_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettings(isPresented: .constant(true))
    }
}

extension Date {
    func formatted(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string(from: self)
    }
}
#endif
