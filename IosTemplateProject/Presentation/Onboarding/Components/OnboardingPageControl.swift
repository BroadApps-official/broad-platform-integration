import SwiftUI

struct OnboardingPageControl: View {
    var selectedPage: Int
    var pageCount: Int
    var accentColor: Color = .specialOrange
    private let circleSize: CGFloat = 7

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: circleSize / 2)
                    .fill(selectedPage == index ? accentColor : Color.white.opacity(0.3))
                    .frame(
                        width: selectedPage == index ? circleSize * 4 : circleSize,
                        height: circleSize
                    )
            }
        }
        .frame(height: 9)
        .animation(.easeInOut(duration: 0.25), value: selectedPage)
    }
}
