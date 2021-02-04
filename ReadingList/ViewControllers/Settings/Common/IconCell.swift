import SwiftUI
import SafariServices

struct IconCell<T>: View where T: View {
    let text: String
    let image: T
    let withChevron: Bool
    let withBadge: String?
    let textForegroundColor: Color

    init(_ text: String, image: T, withChevron: Bool = false, withBadge: String? = nil, textForegroundColor: Color = Color(.label)) {
        self.text = text
        self.image = image
        self.withChevron = withChevron
        self.withBadge = withBadge
        self.textForegroundColor = textForegroundColor
    }

    init(_ text: String, imageName systemImageName: String, backgroundColor: Color, withChevron: Bool = false, withBadge: String? = nil, textForegroundColor: Color = Color(.label)) where T == SystemSettingsIcon {
        self.init(text, image: SystemSettingsIcon(systemImageName: systemImageName, backgroundColor: backgroundColor), withChevron: withChevron, withBadge: withBadge, textForegroundColor: textForegroundColor)
    }

    var body: some View {
        // The button is only used to get the touch-down colour effect
        Button(action: {}) {
            HStack(spacing: 12) {
                image
                Text(text)
                    .font(.body)
                    .foregroundColor(textForegroundColor)
                Spacer()
                if let withBadge = withBadge {
                    ZStack {
                        Circle()
                            .frame(width: 24, height: 24, alignment: .trailing)
                            .foregroundColor(Color(.systemRed))
                        Text(withBadge)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                if withChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14.0, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .contentShape(Rectangle())
    }
}

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
        }.frame(width: 29, height: 29, alignment: .center)
        .cornerRadius(8)
    }
}

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
