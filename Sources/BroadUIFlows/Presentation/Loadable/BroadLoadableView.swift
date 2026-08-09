import BroadCore
import SwiftUI

@MainActor
public struct BroadLoadableView<
    Value: Sendable,
    ContentView: View,
    IdleView: View,
    LoadingView: View,
    RefreshView: View,
    EmptyContentView: View,
    StaleView: View,
    FailureView: View
>: View {
    private let state: LoadableState<Value>
    private let content: @MainActor (Value) -> ContentView
    private let idle: @MainActor () -> IdleView
    private let loading: @MainActor () -> LoadingView
    private let refreshIndicator: @MainActor () -> RefreshView
    private let empty: @MainActor () -> EmptyContentView
    private let staleBanner: @MainActor (AppError?) -> StaleView
    private let failure: @MainActor (AppError, Value?) -> FailureView

    public init(
        state: LoadableState<Value>,
        @ViewBuilder content: @escaping @MainActor (Value) -> ContentView,
        @ViewBuilder idle: @escaping @MainActor () -> IdleView,
        @ViewBuilder loading: @escaping @MainActor () -> LoadingView,
        @ViewBuilder refreshIndicator: @escaping @MainActor () -> RefreshView,
        @ViewBuilder empty: @escaping @MainActor () -> EmptyContentView,
        @ViewBuilder staleBanner: @escaping @MainActor (AppError?) -> StaleView,
        @ViewBuilder failure: @escaping @MainActor (AppError, Value?) -> FailureView
    ) {
        self.state = state
        self.content = content
        self.idle = idle
        self.loading = loading
        self.refreshIndicator = refreshIndicator
        self.empty = empty
        self.staleBanner = staleBanner
        self.failure = failure
    }

    public var body: some View {
        VStack(spacing: 0) {
            staleStatus
            renderedContent
        }
        .overlay(alignment: .topTrailing) {
            if isRefreshing {
                refreshIndicator()
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        switch state {
        case .idle:
            idle()
        case .loading(previousValue: nil):
            loading()
        case let .loading(previousValue: .some(value)),
             let .loaded(value),
             let .stale(value: value, error: _):
            content(value)
        case .empty:
            empty()
        case let .error(error, previousValue):
            failure(error, previousValue)
        @unknown default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var staleStatus: some View {
        if case let .stale(_, error) = state {
            staleBanner(error)
        }
    }

    private var isRefreshing: Bool {
        if case .loading(previousValue: .some) = state {
            return true
        }

        return false
    }
}
