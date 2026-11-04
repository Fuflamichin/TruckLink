#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --platforms=windows --project-name trucklink_desktop --org com.trucklink -t app --no-pub apps/desktop
flutter create --platforms=android,ios --project-name trucklink_mobile --org com.trucklink -t app --no-pub apps/mobile
rm -f apps/desktop/test/widget_test.dart apps/mobile/test/widget_test.dart
flutter pub get
