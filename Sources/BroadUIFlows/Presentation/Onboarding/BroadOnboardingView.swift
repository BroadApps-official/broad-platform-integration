import SwiftUI

@MainActor
public struct BroadOnboardingView<Media: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel: OnboardingViewModel

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
        _viewModel = StateObject(wrappedValue: viewModel)
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
        Group {
            if viewModel.configuration.isValid {
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: theme.metrics.pageSpacing) {
                            pageContent

                            Spacer(minLength: theme.metrics.controlSpacing)

                            controls
                        }
                        .padding(theme.metrics.screenPadding)
                        .frame(
                            minHeight: proxy.size.height,
                            alignment: .top
                        )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .background(theme.palette.background.ignoresSafeArea())
        .background(windowVisibilityObserver)
        .onAppear {
            viewModel.onboardingDidAppear()
            viewModel.applicationActiveDidChange(scenePhase == .active)
            if viewModel.completeInvalidConfigurationIfNeeded() {
                onCompleted()
            }
        }
        .onDisappear {
            viewModel.onboardingDidDisappear()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            viewModel.applicationActiveDidChange(phase == .active)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
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
            .onAppear {
                if viewModel.currentIndex == viewModel.configuration.pages.startIndex {
                    viewModel.firstSlideDidAppear()
                }
            }
            .onDisappear {
                if page.id == viewModel.configuration.pages.first?.id {
                    viewModel.firstSlideDidDisappear()
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: theme.metrics.controlSpacing) {
            pageProgress

            Button(action: advance) {
                Text(actionTitle)
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

            footerLinks
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

    private var pageProgress: some View {
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
    private var footerLinks: some View {
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

    private var windowVisibilityObserver: some View {
        OnboardingWindowVisibilityView { isVisible, validateCurrentVisibility in
            viewModel.windowVisibilityDidChange(
                isVisible,
                validateCurrentVisibility: validateCurrentVisibility
            )
        }
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var actionTitle: String {
        viewModel.isLastPage
            ? viewModel.configuration.completionTitle
            : viewModel.configuration.continueTitle
    }

    private func advance() {
        if viewModel.advance() {
            onCompleted()
        }
    }
}
