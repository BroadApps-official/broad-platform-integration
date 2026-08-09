import BroadMonetization
import Swinject

public final class BroadUIFlowsAssembly: Assembly {
    public init() {}

    public func assemble(container: Container) {
        container
            .register(BroadUIFlowsModule.self) { resolver in
                guard let monetizationModule = resolver.resolve(BroadMonetizationModule.self) else {
                    preconditionFailure("BroadMonetizationAssembly must be registered before BroadUIFlowsAssembly")
                }

                return BroadUIFlowsModule(
                    monetizationIdentifier: monetizationModule.identifier
                )
            }
            .inObjectScope(.container)
    }
}
