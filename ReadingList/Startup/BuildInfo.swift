import Foundation
import ReadingList_Foundation

struct BuildInfo: Codable {
    enum BuildType: Int, Codable {
        case debug, testFlight, appStore //swiftlint:disable:this explicit_enum_raw_value
    }

    init(version: Version, buildNumber: Int, type: BuildType) {
        self.version = version
        self.buildNumber = buildNumber
        self.type = type
    }

    static var thisBuild: BuildInfo = {
        guard let bundleShortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let version = Version(bundleShortVersion) else { preconditionFailure() }

        guard let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let buildNumber = Int(bundleVersion) else { preconditionFailure() }

        let buildType: BuildType

        #if DEBUG || arch(i386) || arch(x86_64)
        buildType = .debug
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            buildType = .testFlight
        } else {
            buildType = .appStore
        }
        #endif
        return BuildInfo(version: version, buildNumber: buildNumber, type: buildType)
    }()

    let version: Version
    let buildNumber: Int
    let type: BuildType

    /// Returns the version suffixed with the build number if this is a Beta build
    var fullDescription: String {
        switch type {
        case .appStore: return "\(version)"
        case .testFlight: return "\(version) (Build \(buildNumber))"
        case .debug: return "\(version) Debug"
        }
    }

    /// Returns the version suffixed with Beta or Debug if this is a TestFlight or Debug build
    var versionAndConfiguration: String {
        switch type {
        case .appStore: return "\(version)"
        case .testFlight: return "\(version) (Beta)"
        case .debug: return "\(version) (Debug)"
        }
    }
}

struct Version: Equatable, Hashable, Comparable, CustomStringConvertible, Codable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ versionString: String) {
        let components = versionString.components(separatedBy: ".")
        if components.count != 3 {
            return nil
        }
        let integerComponents = components.compactMap(Int.init)
        if integerComponents.count != 3 {
            return nil
        }
        self.major = integerComponents[0]
        self.minor = integerComponents[1]
        self.patch = integerComponents[2]
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
