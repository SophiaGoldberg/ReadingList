import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension SharedBookData {
    func coverUiImage() -> UIImage {
        if let coverData = coverImage, let uiImage = UIImage(data: coverData) {
            return uiImage
        } else {
            return UIImage(named: "CoverPlaceholder_White")!
        }
    }
}

extension Date {
    var start: Date {
        Calendar.current.startOfDay(for: self)
    }

    func addingDays(_ count: Int) -> Date {
        var addedDays = DateComponents()
        addedDays.day = count
        guard let newDate = Calendar.current.date(byAdding: addedDays, to: self) else {
            preconditionFailure("Unexpected nil Date by adding \(count) days to \(self)")
        }
        return newDate
    }

    func daysUntil(_ otherDate: Date) -> Int {
        let dateComponents = Calendar.current.dateComponents([.day], from: self.start, to: otherDate.start)
        guard let daysBetween = dateComponents.day else {
            assertionFailure("Unexpected nil day component")
            return 0
        }
        return daysBetween
    }
}

extension Bundle {
    func decodedData<T>(as type: T.Type, jsonFileName fileName: String) -> T where T: Decodable {
        let dataPath = Bundle.main.url(forResource: fileName, withExtension: "json")!
        let data = try! Data(contentsOf: dataPath)
        return try! JSONDecoder().decode(T.self, from: data)
    }
}
