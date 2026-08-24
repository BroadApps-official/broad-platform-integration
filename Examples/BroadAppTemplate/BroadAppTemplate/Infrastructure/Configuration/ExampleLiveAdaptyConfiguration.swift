import BroadMonetization
import Foundation

struct ExampleLiveAdaptyConfiguration {
    let platform: AdaptyPlatformConfiguration
    let placements: AdaptyPlacementRegistry

    static func load(
        arguments: [String],
        bundle: Bundle = .main
    ) -> ExampleLiveAdaptyConfiguration? {
        let fallbackFileName = bundle.liveAdaptyFallbackFileName
        let fallbackFileURL = bundle.liveAdaptyFallbackFileURL
        guard arguments.contains("-live-adapty"),
              bundle.liveAdaptyEnabled,
              fallbackFileName == nil || fallbackFileURL != nil,
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
                  subject: .anonymous,
                  fallbackFileURL: fallbackFileURL
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
            (.proIcon, "BroadAppsAdaptyProIconPlacementID"),
            (.settings, "BroadAppsAdaptySettingsPlacementID"),
            (.ctr, "BroadAppsAdaptyCTRPlacementID"),
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

    var liveAdaptyFallbackFileName: String? {
        nonEmptyString(for: "BroadAppsAdaptyFallbackFileName")
    }

    var liveAdaptyFallbackFileURL: URL? {
        guard let fileName = liveAdaptyFallbackFileName else {
            return nil
        }
        let fileURL = URL(fileURLWithPath: fileName)
        let resource = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension.isEmpty
            ? "json"
            : fileURL.pathExtension
        return url(forResource: resource, withExtension: fileExtension)
    }

    func nonEmptyString(for key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed != value ? nil : value
    }
}
