import SwiftUI

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

// Taken from: https://gist.github.com/alexito4/4a9a7c6e3dc447a4f762cf1cf7346b5e
public extension View {
    @available(iOS, obsoleted: 15.0, message: "SwiftUI.View.task is available on iOS 15.")
    @_disfavoredOverload
    @inlinable func task(
        priority: _Concurrency.TaskPriority = .userInitiated,
        @_inheritActorContext _ action: @escaping @Sendable () async -> Swift.Void
    ) -> some SwiftUI.View {
        modifier(MyTaskModifier(priority: priority, action: action))
    }
}

public struct MyTaskModifier: ViewModifier {
    private var priority: TaskPriority
    private var action: @Sendable () async -> Void

    public init(
        priority: TaskPriority,
        action: @escaping @Sendable () async -> Void
    ) {
        self.priority = priority
        self.action = action
        self.task = nil
    }

    @State private var task: Task<Void, Never>?

    public func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .task(priority: priority, action)
        } else {
            content
                .onAppear {
                    self.task = Task {
                        await action()
                    }
                }
                .onDisappear {
                    self.task?.cancel()
                }
        }
    }
}

// I adapted this modifier for `task(id:)` (@louis1001)

public extension View {
    @available(iOS, obsoleted: 15.0, message: "SwiftUI.View.task(id:) is available on iOS 15.")
    @_disfavoredOverload
    @inlinable func task<T>(id value: T, priority: _Concurrency.TaskPriority = .userInitiated, _ action: @escaping @Sendable @MainActor() async -> Void) -> some View where T : Equatable {
        modifier(MyTaskIdModifier(value: value, priority: priority, action: action))
    }
}

public struct MyTaskIdModifier<T: Equatable>: ViewModifier {
    private var value: T
    private var priority: TaskPriority
    private var action: @Sendable () async -> Void

    public init(
        value: T,
        priority: TaskPriority,
        action: @escaping @Sendable () async -> Void
    ) {
        self.value = value
        self.priority = priority
        self.action = action
        self.task = nil
    }

    @State private var task: Task<Void, Never>?

    public func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .task(id: value, priority: priority, action)
        } else {
            content
                .onChange(of: value) {newValue in
                    self.task?.cancel()
                    
                    self.task = Task {
                        await action()
                    }
                }
                .onDisappear {
                    self.task?.cancel()
                }
        }
    }
}
