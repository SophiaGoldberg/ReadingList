import SwiftUI
import SafariServices

@available(iOS 13.0, *)
struct SettingsCell<T>: View where T: View {
    let text: String
    let image: T
    let withChevron: Bool

    init(_ text: String, image: T, withChevron: Bool = false) {
        self.text = text
        self.image = image
        self.withChevron = withChevron
    }

    init(_ text: String, imageName systemImageName: String, color backgroundColor: Color, withChevron: Bool = false) where T == SystemSettingsIcon {
        self.init(text, image: SystemSettingsIcon(systemImageName: systemImageName, backgroundColor: backgroundColor), withChevron: withChevron)
    }

    var body: some View {
        HStack(spacing: 12) {
            image
            Text(text).font(.body)
            Spacer()
            if withChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14.0, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
    }
}

@available(iOS 13.0, *)
struct SettingsIcon<Image>: View where Image: View {
    let image: Image
    let backgroundColor: Color

    init(color backgroundColor: Color, @ViewBuilder image: () -> Image) {
        self.image = image()
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).foregroundColor(backgroundColor)
            image
        }.frame(width: 30, height: 30, alignment: .center)
        .cornerRadius(8)
    }
}

@available(iOS 13.0, *)
struct SystemSettingsIcon: View {
    let systemImageName: String
    let backgroundColor: Color

    var body: some View {
        SettingsIcon(color: backgroundColor) {
            Image(systemName: systemImageName)
                .foregroundColor(.white)
                .font(.system(size: 16))
        }
    }
}

@available(iOS 13.0, *)
struct SettingsCell_Previews: PreviewProvider {
    static var previews: some View {
        SettingsCell("Hello", imageName: "chevron.right", color: .red)
    }
}
