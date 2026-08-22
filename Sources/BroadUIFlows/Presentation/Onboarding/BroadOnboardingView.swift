import SwiftUI

@MainActor
public struct BroadOnboardingView<Media: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let viewModel: OnboardingViewModel
    private let theme: BroadOnboardingTheme
    private let media: @MainActor (OnboardingMediaDescriptor) -> Media
    private let onFooterAction: @MainActor (OnboardingFooterDestination) -> Void
    private let onCompleted: @MainActor () -> Void

    public init(
        viewModel: OnboardingViewModel,
        theme: BroadOnboardingTheme,
        @ViewBuilder media: @escaping @MainActor (OnboardingMediaDescriptor) -> Media,
        onFooterAction: @escaping @MainActor (OnboardingFooterDestination) -> Void,
        onCompleted: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.theme = theme
        self.media = media
        self.onFooterAction = onFooterAction
        self.onCompleted = onCompleted
    }

    public init(
        viewModel: OnboardingViewModel,
        @ViewBuilder media: @escaping @MainActor (OnboardingMediaDescriptor) -> Media,
        onFooterAction: @escaping @MainActor (OnboardingFooterDestination) -> Void,
        onCompleted: @escaping @MainActor () -> Void
    ) {
        self.init(
            viewModel: viewModel,
            theme: .standard,
            media: media,
            onFooterAction: onFooterAction,
            onCompleted: onCompleted
        )
    }

    public var body: some View {
        BroadOnboardingFlowHost(
            viewModel: viewModel,
            onCompleted: onCompleted
        ) { viewModel, actions in
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: theme.metrics.pageSpacing) {
                        pageContent(viewModel: viewModel)

                        Spacer(minLength: theme.metrics.controlSpacing)

                        controls(
                            viewModel: viewModel,
                            advance: actions.advance
                        )
                    }
                    .padding(theme.metrics.screenPadding)
                    .frame(
                        minHeight: proxy.size.height,
                        alignment: .top
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(theme.palette.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func pageContent(viewModel: OnboardingViewModel) -> some View {
        if let page = viewModel.currentPage {
            VStack(spacing: theme.metrics.pageSpacing) {
                media(page.media)
                    .frame(maxWidth: .infinity)

                VStack(spacing: theme.metrics.textSpacing) {
                    Text(page.title)
                        .font(theme.typography.title)
                        .foregroundStyle(theme.palette.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle = page.subtitle {
                        Text(subtitle)
                            .font(theme.typography.subtitle)
                            .foregroundStyle(theme.palette.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .id(page.id)
            .transition(reduceMotion ? .identity : .opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page.id)
        }
    }

    private func controls(
        viewModel: OnboardingViewModel,
        advance: @escaping @MainActor () -> Void
    ) -> some View {
        VStack(spacing: theme.metrics.controlSpacing) {
            pageProgress(viewModel: viewModel)

            Button(action: advance) {
                Text(actionTitle(viewModel: viewModel))
                    .font(theme.typography.action)
                    .foregroundStyle(theme.palette.actionForeground)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(
                            theme.metrics.minimumActionHeight,
                            BroadOnboardingTheme.Metrics.minimumInteractiveDimension
                        )
                    )
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.palette.accent)

            footerLinks(viewModel: viewModel)
        }
        .padding(theme.metrics.surfacePadding)
        .background(
            RoundedRectangle(
                cornerRadius: theme.metrics.cornerRadius,
                style: .continuous
            )
            .fill(theme.palette.surface)
            .overlay {
                RoundedRectangle(
                    cornerRadius: theme.metrics.cornerRadius,
                    style: .continuous
                )
                .stroke(
                    theme.palette.border,
                    lineWidth: theme.metrics.borderWidth
                )
            }
        )
    }

    private func pageProgress(viewModel: OnboardingViewModel) -> some View {
        HStack(spacing: theme.metrics.progressSpacing) {
            ForEach(viewModel.configuration.pages) { page in
                Capsule(style: .continuous)
                    .fill(
                        page.id == viewModel.currentPage?.id
                            ? theme.palette.accent
                            : theme.palette.progressInactive
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: theme.metrics.progressHeight,
                        maxHeight: theme.metrics.progressHeight
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.configuration.progressAccessibilityLabel))
        .accessibilityValue(
            Text("\(viewModel.currentIndex + 1) / \(viewModel.configuration.pages.count)")
        )
    }

    @ViewBuilder
    private func footerLinks(viewModel: OnboardingViewModel) -> some View {
        if !viewModel.configuration.footerLinks.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    ForEach(viewModel.configuration.footerLinks) { link in
                        footerButton(link)
                    }
                }

                VStack(spacing: theme.metrics.textSpacing) {
                    ForEach(viewModel.configuration.footerLinks) { link in
                        footerButton(link)
                    }
                }
            }
        }
    }

    private func footerButton(
        _ link: OnboardingFooterLinkConfiguration
    ) -> some View {
        Button {
            onFooterAction(link.destination)
        } label: {
            Text(link.title)
                .font(theme.typography.footer)
                .foregroundStyle(theme.palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(
                    maxWidth: .infinity,
                    minHeight: BroadOnboardingTheme.Metrics.minimumInteractiveDimension
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(link.accessibilityLabel ?? link.title))
    }

    private func actionTitle(viewModel: OnboardingViewModel) -> String {
        viewModel.isLastPage
            ? viewModel.configuration.completionTitle
            : viewModel.configuration.continueTitle
    }
}
