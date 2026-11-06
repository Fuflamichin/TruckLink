import 'package:flutter_test/flutter_test.dart';
import 'package:trucklink_mobile/core/appearance/appearance_settings.dart';

void main() {
  group('TruckLink appearance settings', () {
    test('defaults preserve the original design', () {
      const settings = TruckLinkAppearanceSettings.defaults;

      expect(settings.accent, TruckLinkAccent.green);

      expect(settings.navigationSize, TruckLinkNavigationSize.standard);

      expect(settings.highlightIntensity, TruckLinkHighlightIntensity.standard);

      expect(settings.cardStyle, TruckLinkCardStyle.filled);

      expect(settings.cornerStyle, TruckLinkCornerStyle.rounded);
    });

    test('settings survive JSON serialization', () {
      const original = TruckLinkAppearanceSettings(
        accent: TruckLinkAccent.violet,
        navigationSize: TruckLinkNavigationSize.compact,
        highlightIntensity: TruckLinkHighlightIntensity.vivid,
        cardStyle: TruckLinkCardStyle.outlined,
        cornerStyle: TruckLinkCornerStyle.extraRounded,
      );

      final encoded = original.toJsonString();

      final restored = TruckLinkAppearanceSettings.fromJsonString(encoded);

      expect(restored, original);
      expect(restored.accent, TruckLinkAccent.violet);
      expect(restored.cardStyle, TruckLinkCardStyle.outlined);
    });

    test('copyWith preserves other settings', () {
      const original = TruckLinkAppearanceSettings.defaults;

      final updated = original.copyWith(accent: TruckLinkAccent.blue);

      expect(updated.accent, TruckLinkAccent.blue);

      expect(updated.navigationSize, original.navigationSize);

      expect(updated.cardStyle, original.cardStyle);

      expect(updated.cornerStyle, original.cornerStyle);
    });

    test('invalid settings are rejected', () {
      expect(
        () => TruckLinkAppearanceSettings.fromJsonString('invalid json'),
        throwsFormatException,
      );

      expect(
        () => TruckLinkAppearanceSettings.fromJsonString('{"version": 999}'),
        throwsFormatException,
      );
    });
  });
}
