import Foundation
import ReadingList_Foundation

extension LanguageIso639_1 {
    // List formed by examining the results count for a Google Books search call with the langRestrict paramater;
    // any language codes which did not change the number of results were removed from the list of codes.
    var canFilterGoogleSearchResults: Bool {
        switch self {
        case .af,
             .ar,
             .hy,
             .be,
             .bg,
             .ca,
             .hr,
             .cs,
             .da,
             .nl,
             .en,
             .eo,
             .et,
             .fi,
             .fr,
             .de,
             .hi,
             .hu,
             .`is`,
             .id,
             .it,
             .ja,
             .ko,
             .lv,
             .lt,
             .el,
             .no,
             .fa,
             .pl,
             .pt,
             .ro,
             .ru,
             .sr,
             .sk,
             .sl,
             .es,
             .sw,
             .sv,
             .tl,
             .th,
             .tr,
             .uk,
             .vi:
            return true
        default:
            return false
        }
    }
}
