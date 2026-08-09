import BroadMonetization
import SwiftUI

@MainActor
public struct BroadPaywallView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject var viewModel: PaywallViewModel
    @State var safariDestination: BroadPaywallSafariDestination?

    let theme: BroadPaywallTheme
    let productFormatter: BroadPaywallProductFormatter
    let onClose: @MainActor () -> Void
    let onCompleted: @MainActor (BroadPaywallCompletion) -> Void

    public init(
        viewModel: PaywallViewModel,
        theme: BroadPaywallTheme,
        productFormatter: BroadPaywallProductFormatter,
        onClose: @escaping @MainActor () -> Void,
        onCompleted: @escaping @MainActor (BroadPaywallCompletion) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.theme = theme
        self.productFormatter = productFormatter
        self.onClose = onClose
        self.onCompleted = onCompleted
    }

    public init(
        viewModel: PaywallViewModel,
        onClose: @escaping @MainActor () -> Void,
        onCompleted: @escaping @MainActor (BroadPaywallCompletion) -> Void
    ) {
        self.init(
            viewModel: viewModel,
            theme: .standard,
            productFormatter: BroadPaywallProductFormatter(),
            onClose: onClose,
            onCompleted: onCompleted
        )
    }

    public var body: some View {
        ZStack {
            theme.palette.background
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                paywallLayout
                    .frame(
                        maxWidth: theme.metrics.sizing.maximumContentWidth,
                        maxHeight: .infinity
                    )

                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(!viewModel.isPurchaseInFlight)
        .onAppear {
            viewModel.viewDidAppear()
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
        .onChange(of: viewModel.completionEvent) { _, event in
            handleCompletionEvent(event)
        }
        .sheet(item: $safariDestination) { destination in
            BroadInAppSafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: checkoutSheetBinding) {
            BroadPaymentMethodSheet(
                methods: viewModel.checkoutMethods,
                copy: viewModel.configuration.copy,
                theme: theme,
                onSelect: viewModel.chooseCheckoutMethod,
                onCancel: viewModel.cancelCheckoutMethodSelection
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var paywallLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: 0) {
                    closeHeader
                    stateBodyContent
                    stickyFooter
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            VStack(spacing: 0) {
                closeHeader
                stateContent
                stickyFooter
            }
        }
    }

    var checkoutSheetBinding: Binding<Bool> {
        Binding(
            get: { !viewModel.checkoutMethods.isEmpty },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelCheckoutMethodSelection()
                }
            }
        )
    }

    func handleCompletionEvent(_ event: BroadPaywallCompletionEvent?) {
        guard let event else {
            return
        }

        viewModel.consumeCompletionEvent(id: event.id)
        onCompleted(event.completion)
    }
}

struct BroadPaywallSafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}
