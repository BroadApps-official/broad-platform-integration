import BroadUIFlows
import SwiftUI

struct RootView: View {
    @ObservedObject private var viewModel: RootViewModel

    init(viewModel: RootViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            AppTokens.Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTokens.Spacing.section) {
                    header

                    loadableSection
                }
                .padding(.horizontal, AppTokens.Spacing.screenHorizontal)
                .padding(.vertical, AppTokens.Spacing.screenVertical)
            }
        }
        .onAppear(perform: viewModel.startIfNeeded)
    }

    private var loadableSection: some View {
        BroadLoadableView(
            state: viewModel.moduleState,
            content: { modules in
                stateContent(modules: modules)
            },
            idle: {
                stateContent(modules: nil)
            },
            loading: {
                stateContent(modules: nil)
            },
            refreshIndicator: {
                EmptyView()
            },
            empty: {
                stateContent(modules: nil)
            },
            staleBanner: { _ in
                EmptyView()
            },
            failure: { _, previousModules in
                stateContent(modules: previousModules)
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTokens.Spacing.small) {
            Text(viewModel.content.eyebrow)
                .font(AppTokens.Font.eyebrow)
                .foregroundStyle(AppTokens.Color.accent)

            Text(viewModel.content.title)
                .font(AppTokens.Font.heroTitle)
                .foregroundStyle(AppTokens.Color.primaryText)

            Text(viewModel.content.subtitle)
                .font(AppTokens.Font.body)
                .foregroundStyle(AppTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moduleList(_ modules: [RootViewModel.ModuleItem]) -> some View {
        VStack(spacing: AppTokens.Spacing.cardGap) {
            ForEach(modules) { module in
                ModuleCardView(module: module)
            }
        }
    }

    private func stateContent(
        modules: [RootViewModel.ModuleItem]?
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTokens.Spacing.section) {
            if let modules {
                moduleList(modules)
            }

            BootstrapStatusCardView(
                state: viewModel.bootstrapStatusCardState,
                onRetry: viewModel.retry
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
