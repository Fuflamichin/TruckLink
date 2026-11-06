import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance_controller.dart';

// ============================================
// GLOBAL APPEARANCE PROVIDER
// ============================================

/// One controller for the entire mobile app.
///
/// Both TruckLinkApp and AppearanceSettingsScreen
/// receive the same controller instance.
///
/// This is important:
/// changing appearance must not create
/// a separate copy of the settings.
final appearanceControllerProvider = Provider<TruckLinkAppearanceController>((
  ref,
) {
  final controller = TruckLinkAppearanceController();

  // Load saved preferences on app startup.
  unawaited(controller.initialize());

  // Riverpod owns the controller lifecycle.
  ref.onDispose(controller.dispose);

  return controller;
});
