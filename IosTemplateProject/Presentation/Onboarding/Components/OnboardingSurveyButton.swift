import SwiftUI

struct OnboardingSurveyButton: View {
    let systemImage: String
    let title: String
    var isSelected: Bool
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.specialGreen.opacity(0.1) : Color.clear)

                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.specialGreen : Color.white.opacity(0.1), lineWidth: 2)

                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.specialWhite)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.specialWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(height: 60)
    }
}
