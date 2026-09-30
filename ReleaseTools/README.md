# Инструмент подготовки релизного проекта приложения

Инструмент копирует пакеты BroadApps внутрь релизного проекта, проверяет исходники и сборку без подписи, затем создаёт отдельную ветку `release/<версия>` для Codemagic. Разработку продолжайте в основной ветке. Codemagic умеет собирать и `.xcodeproj`, и `.xcworkspace`; нужный путь выбирается в нашем релизном инструменте и шаблоне CI.

## Установка

Из корня репозитория `broad-platform-integration` запустите одну из команд. Первый путь — корень Git-репозитория приложения, затем путь относительно него и имя схемы:

```bash
# Xcode project only
bash ReleaseTools/install.sh /path/to/App ios/App.xcodeproj AppScheme

# CocoaPods workspace; it may not exist before pod install
bash ReleaseTools/install.sh /path/to/App ios/App.xcodeproj AppScheme --workspace ios/App.xcworkspace

# Custom workspace without CocoaPods
bash ReleaseTools/install.sh /path/to/App ios/App.xcworkspace AppScheme
```

Если в workspace несколько проектов приложения, добавьте `--project ios/App.xcodeproj`. Для Podfile вне каталога проекта или workspace добавьте `--podfile path/to/Podfile`. Пути с пробелами заключайте в кавычки. У схемы должна быть отметка **Shared** в Xcode: **Product → Scheme → Manage Schemes**. Сохраните общий `.xcscheme` в Git. Установщик проверит схему и не перезапишет существующий релизный инструмент.

Установщик копирует скрипты и универсальный `Scripts/codemagic.release.yaml`, если его ещё нет, и добавляет `ReleaseExport/`, `ReleaseBranches/`, `ReleaseRecords/` в `.gitignore`. Настройте в шаблоне `XCODE_PROJECT`, `XCODE_WORKSPACE` (пустая строка для сборки проекта), при необходимости `XCODE_PODFILE`, схему, плейсхолдеры подписи и публикацию. Файл из `Scripts/` копируется в корень релизной ветки как `codemagic.yaml`. Проверьте diff и сохраните файлы приложения в коммит.

## Подготовка

Из корня приложения выполните `bash Scripts/prepare_release.sh`. Wrapper передаёт выбранные `--project`, `--workspace`, `--podfile` и `--scheme`. Ruby инструмент также принимает эти параметры напрямую. Путь `.xcworkspace` в `--project` понимается как workspace; без явного проекта инструмент выбирает ровно один проект с app target и пакетами BroadApps. При неоднозначности передайте `--project` отдельно.

Подготовка копирует tracked-файлы во временную папку, кроме заметок разработчика (`docs/`, `Documentation/*.md`, README, `AGENTS.md`, `CLAUDE.md`): они не нужны для сборки и часто содержат ссылки на репозитории платформы. При наличии Podfile там сначала выполняется `pod install --deployment` из его каталога. Затем resolve выполняется через workspace, если он задан или создан CocoaPods, иначе через project. Все проекты workspace с пакетами BroadApps переключаются на общую `LocalPlatform/`, с путём относительно каждого `.xcodeproj`. После этого идут аудит Git-ссылок, resolve и unsigned Release build через тот же контейнер и схему. Без `--skip-build` успешный экспорт создаёт ветку `release/<версия>` и отправляет её в GitHub; `--export-only` оставляет только локальную копию.

В Codemagic выберите созданную ветку. Шаблон проверяет ветку и исходники, устанавливает Pods при наличии Podfile, делает resolve, повторно проверяет исходники, настраивает подпись, увеличивает build number, собирает IPA из workspace или project и проверяет IPA перед публикацией. `check_release_artifact.rb` получает путь проекта через `--project`; при ручном вызове можно использовать `XCODE_PROJECT`. Проверки ссылок на Git BroadApps и служебного отчёта внутри IPA остаются обязательными.

### CocoaPods и Xcode 27

У старых подов минимальная версия iOS ниже 15, и Xcode 27 не собирает их. Добавьте в `Podfile` блок `post_install`, который выставляет `IPHONEOS_DEPLOYMENT_TARGET` подов по минимальной версии приложения, выполните `pod install` и сохраните `Podfile` и `Podfile.lock`. Если команда упала на этой ошибке, инструмент покажет строки `error:` и подсказку.

Локальный отчёт `ReleaseRecords/<версия>.json` остаётся вне релизной ветки. CI создаёт отдельный отчёт как artifact. Подробная [инструкция для разработчика](https://broadapps-ios-docs.nkhsnv.chatgpt.site/docs/app-release-export).
