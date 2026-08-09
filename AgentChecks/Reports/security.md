# Security — post-fix отчёт

Дата: 2026-08-09
Вердикт: `BLOCKED`
Source snapshot SHA-256: `4853d9f2ccbc11e7995ba6cb07291cc8770c59effbbb24f3d10a49fe862a26d4`
Reviewed at UTC: `2026-08-09T05:41:55Z`
Acceptance run ID: `1c16dff2-dabd-4998-af40-5645e7b5f49f`
Host bundle IDs: `N/A`

## Команды

- `bash Scripts/check_sensitive_data.sh`
- `bash Scripts/check_privacy_manifest.sh`
- `BROADAPPS_GATE_MODE=local bash Scripts/release_gate.sh`

## Проверено

- sensitive scan прошёл по Swift/config/docs/strings/xcstrings/xcprivacy/storekit;
- source privacy plist валиден и содержит UserDefaults reasons `CA92.1` и `1C8F.1`;
- Release `iphoneos` app и свежий unsigned `.xcarchive` содержат именно `BroadAppsIOSPlatform_BroadCore.bundle/PrivacyInfo.xcprivacy` с обоими reasons;
- все bundled privacy plist прошли `plutil -lint`;
- exact dependency pins: Adapty `3.17.3`, Swinject `2.10.0`.
- production gate snapshots reports privately, binds them to one digest/run and
  rechecks report evidence and source digest after build to close TOCTOU substitution;
- distribution acceptance проверяет exact IPA/CDHash/profile/privacy evidence,
  но локальный unsigned archive не выдаётся за App Store Connect export.

## Findings

Findings: нет.

## Неподтверждённые риски

Нет двух exact real-host App Store Connect `.ipa`, matching attestations,
App Store Connect validation/privacy results и review production host
secrets/analytics export. Это app-owned acceptance, а не доказанный
defect package.

## Итог

Локальный package/archive privacy и sensitive-data scope готовы;
production-вердикт ждёт exact App Store Connect `.ipa`, matching
attestations и App Store Connect validation/privacy evidence.
