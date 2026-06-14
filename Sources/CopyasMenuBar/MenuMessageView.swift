import SwiftUI

struct MenuMessageView: View {
    enum Style {
        case error
        case success
        case info
    }

    let title: String?
    let message: String
    var style: Style = .info

    init(title: String? = nil, message: String, style: Style = .info) {
        self.title = title
        self.message = message
        self.style = style
    }

    private let maxWidth: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(titleColor)
            }

            Text(message)
                .font(.callout)
                .foregroundStyle(messageColor)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(true)
    }

    private var titleColor: Color {
        switch style {
        case .error:
            .primary
        case .success, .info:
            .secondary
        }
    }

    private var messageColor: Color {
        switch style {
        case .error:
            .secondary
        case .success, .info:
            .secondary
        }
    }
}
