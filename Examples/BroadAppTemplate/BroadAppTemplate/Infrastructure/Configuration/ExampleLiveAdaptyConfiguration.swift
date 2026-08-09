import BroadMonetization
import Foundation

struct ExampleLiveAdaptyConfiguration {
    let platform: AdaptyPlatformConfiguration
    let placements: AdaptyPlacementRegistry

    static func load(
        arguments: [String],
        bundle: Bundle = .main
    ) -> ExampleLiveAdaptyConfiguration? {
        guard arguments.contains("-live-adapty"),
              bundle.liveAdaptyEnabled,
              let apiKey = bundle.nonEmptyString(for: "BroadAppsAdaptyAPIKey"),
              let accessLevelID = bundle.nonEmptyString(
                  for: "BroadAppsAdaptyAccessLevelID"
              ),
              let mainPlacement = bundle.nonEmptyString(
                  for: "BroadAppsAdaptyMainPlacementID"
              ),
              let platform = AdaptyPlatformConfiguration(
                  apiKey: apiKey,
                  accessLevelID: accessLevelID,
                  subject: .anonymous
              )
        else {
            return nil
        }

        return ExampleLiveAdaptyConfiguration(
            platform: platform,
            placements: AdaptyPlacementRegistry(
                main: AdaptyPlacementID(rawValue: mainPlacement),
                mappings: bundle.liveAdaptyPlacementMappings
            )
        )
    }
}

private extension Bundle {
    var liveAdaptyEnabled: Bool {
        if let value = object(forInfoDictionaryKey: "BroadAppsLiveAdaptyEnabled") as? Bool {
            return value
        }
        return nonEmptyString(for: "BroadAppsLiveAdaptyEnabled")?
            .caseInsensitiveCompare("yes") == .orderedSame
    }

    var liveAdaptyPlacementMappings: [PlacementID: AdaptyPlacementID] {
        let keys: [(PlacementID, String)] = [
            (.onboarding, "BroadAppsAdaptyOnboardingPlacementID"),
            (.settings, "BroadAppsAdaptySettingsPlacementID"),
            (.feature, "BroadAppsAdaptyFeaturePlacementID"),
            (.tokens, "BroadAppsAdaptyTokensPlacementID"),
            (.discount, "BroadAppsAdaptyDiscountPlacementID"),
            (.specialOffer, "BroadAppsAdaptySpecialOfferPlacementID")
        ]
        return Dictionary(
            uniqueKeysWithValues: keys.compactMap { placement, key in
                nonEmptyString(for: key).map {
                    (placement, AdaptyPlacementID(rawValue: $0))
                }
            }
        )
    }

    func nonEmptyString(for key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed != value ? nil : value
    }
}
