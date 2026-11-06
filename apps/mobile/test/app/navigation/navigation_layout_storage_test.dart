import 'package:flutter_test/flutter_test.dart';
import 'package:trucklink_mobile/app/navigation/navigation_layout_storage.dart';

void main() {
  test('legacy v1 preferences remain readable', () {
    const old = '''
    {
      "version": 1,
      "bottom": ["home", "instruments"],
      "more": ["truck", "job"],
      "hidden": ["statistics"]
    }
    ''';

    final layout = SavedNavigationLayout.fromJsonString(old);
    expect(layout.bottomIds, ['home', 'instruments']);
    expect(layout.moreIds, ['truck', 'job']);
    expect(layout.hiddenIds, ['statistics']);
    expect(layout.groups, isEmpty);
  });

  test('combined tab survives v2 JSON round-trip', () {
    final layout = SavedNavigationLayout(
      bottomIds: ['home', 'group:cockpit', 'truck'],
      moreIds: ['job', 'instruments'],
      hiddenIds: ['statistics'],
      groups: [
        SavedNavigationGroup(
          id: 'group:cockpit',
          title: 'Кабина',
          memberIds: ['instruments', 'truck'],
        ),
      ],
    );

    // Group members cannot simultaneously appear as independent tabs.
    expect(layout.bottomIds, ['home', 'group:cockpit']);
    expect(layout.moreIds, ['job']);

    final restored = SavedNavigationLayout.fromJsonString(
      layout.toJsonString(),
    );
    expect(restored.bottomIds, ['home', 'group:cockpit']);
    expect(restored.moreIds, ['job']);
    expect(restored.hiddenIds, ['statistics']);
    expect(restored.groups.single.title, 'Кабина');
    expect(restored.groups.single.memberIds, ['instruments', 'truck']);
  });

  test('existing settings screens can still save without groups', () {
    final layout = SavedNavigationLayout(
      bottomIds: ['home', 'truck'],
      moreIds: ['job'],
    );
    expect(layout.groups, isEmpty);
    expect(
      SavedNavigationLayout.fromJsonString(layout.toJsonString()).bottomIds,
      ['home', 'truck'],
    );
  });

  test('invalid or nested groups are rejected', () {
    expect(
      () => SavedNavigationGroup(
        id: 'group:invalid',
        title: 'Тест',
        memberIds: ['home', 'group:other'],
      ),
      throwsArgumentError,
    );
  });
}
