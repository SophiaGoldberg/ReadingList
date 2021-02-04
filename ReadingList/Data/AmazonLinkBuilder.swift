import Foundation

struct AmazonAffiliateLinkBuilder {
    let topLevelDomain: String
    let tag: String?

    init(locale: Locale) {
        topLevelDomain = Self.topLevelDomain(from: locale.regionCode)
        tag = Self.tag(from: locale.regionCode)
    }

    private static func topLevelDomain(from regionCode: String?) -> String { //swiftlint:disable:this cyclomatic_complexity
        switch regionCode {
        case "US": return ".com"
        case "CA": return ".ca"
        case "MX": return ".com.mx"
        case "AU": return ".com.au"
        case "GB": return ".co.uk"
        case "DE": return ".de"
        case "IT": return ".it"
        case "FR": return ".fr"
        case "ES": return ".es"
        case "NL": return ".nl"
        case "SE": return ".se"
        case "CN": return ".cn"
        case "BR": return ".com.br"
        case "IN": return ".in"
        case "JP": return ".co.jp"
        default: return ".com"
        }
    }

    private static func tag(from regionCode: String?) -> String? {
        switch regionCode {
        case "GB": return "&tag=readinglistio-21"
        case "US": return "&tag=readinglistio-20"
        default: return nil
        }
    }

    func buildAffiliateLink(fromIsbn13 isbn13: Int64) -> URL? {
        return URL(string: "https://www.amazon\(topLevelDomain)/s?k=\(isbn13.string)&i=stripbooks\(tag ?? "")")
    }
}
