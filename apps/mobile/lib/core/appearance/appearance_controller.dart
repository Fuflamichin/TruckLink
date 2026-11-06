import 'package:flutter/foundation.dart';

import 'appearance_settings.dart';
import 'appearance_settings_storage.dart';

// ============================================
// TRUCKLINK APPEARANCE CONTROLLER
// ============================================

class TruckLinkAppearanceController extends ChangeNotifier {
  TruckLinkAppearanceController({AppearanceSettingsStorage? storage})
    : _storage = storage ?? AppearanceSettingsStorage();

  // ==========================================
  // STORAGE
  // ==========================================

  final AppearanceSettingsStorage _storage;

  // ==========================================
  // CURRENT SETTINGS
  // ==========================================

  TruckLinkAppearanceSettings _settings = TruckLinkAppearanceSettings.defaults;

  TruckLinkAppearanceSettings get settings => _settings;

  // ==========================================
  // CONTROLLER STATE
  // ==========================================

  bool _isReady = false;
  bool _isDisposed = false;

  int _revision = 0;

  String? _errorMessage;

  Future<void>? _initialization;

  bool get isReady => _isReady;

  String? get errorMessage => _errorMessage;

  // ==========================================
  // INITIALIZE
  // ==========================================

  /// Load saved appearance once.
  ///
  /// Until loading completes, default settings
  /// remain available.
  Future<void> initialize() {
    return _initialization ??= _loadSettings();
  }

  Future<void> _loadSettings() async {
    final revisionAtStart = _revision;

    try {
      final saved = await _storage.load();

      if (_isDisposed) {
        return;
      }

      // A user action may happen while settings
      // are loading. Never overwrite that edit
      // with an older stored snapshot.
      if (_revision == revisionAtStart) {
        if (saved != null) {
          _settings = saved;
        }

        _errorMessage = null;
      }
    } catch (error) {
      debugPrint('TruckLink: appearance load failed: $error');

      if (!_isDisposed && _revision == revisionAtStart) {
        _errorMessage = 'Не удалось загрузить оформление.';
      }
    } finally {
      if (!_isDisposed) {
        _isReady = true;
        notifyListeners();
      }
    }
  }

  // ==========================================
  // APPLY SETTINGS
  // ==========================================

  /// Updates the UI immediately and then
  /// persists the new values.
  ///
  /// Callers can await the returned Future
  /// to handle a storage failure.
  Future<void> apply(TruckLinkAppearanceSettings next) {
    return _update(next);
  }

  Future<void> _update(
    TruckLinkAppearanceSettings next, {
    bool clearStorage = false,
  }) async {
    if (_isDisposed) {
      throw StateError('Appearance controller is disposed');
    }

    // Avoid unnecessary rebuilds and writes.
    if (!clearStorage && next == _settings) {
      return;
    }

    final currentRevision = ++_revision;

    // Apply locally before the first await.
    // This gives an instant visual response.
    _settings = next;
    _errorMessage = null;

    notifyListeners();

    try {
      if (clearStorage) {
        await _storage.reset();
      } else {
        await _storage.save(next);
      }
    } catch (error) {
      debugPrint('TruckLink: appearance save failed: $error');

      // Only the latest failed operation
      // should affect the visible error state.
      if (!_isDisposed && currentRevision == _revision) {
        _errorMessage = 'Не удалось сохранить оформление.';

        notifyListeners();
      }

      rethrow;
    }
  }

  // ==========================================
  // ACCENT COLOR
  // ==========================================

  Future<void> setAccent(TruckLinkAccent accent) {
    return _update(_settings.copyWith(accent: accent));
  }

  // ==========================================
  // NAVIGATION SIZE
  // ==========================================

  Future<void> setNavigationSize(TruckLinkNavigationSize size) {
    return _update(_settings.copyWith(navigationSize: size));
  }

  // ==========================================
  // ACTIVE HIGHLIGHT
  // ==========================================

  Future<void> setHighlightIntensity(TruckLinkHighlightIntensity intensity) {
    return _update(_settings.copyWith(highlightIntensity: intensity));
  }

  // ==========================================
  // CARD APPEARANCE
  // ==========================================

  Future<void> setCardStyle(TruckLinkCardStyle style) {
    return _update(_settings.copyWith(cardStyle: style));
  }

  // ==========================================
  // CORNER ROUNDING
  // ==========================================

  Future<void> setCornerStyle(TruckLinkCornerStyle style) {
    return _update(_settings.copyWith(cornerStyle: style));
  }

  // ==========================================
  // RESTORE DEFAULTS
  // ==========================================

  /// Restore the original TruckLink look:
  ///
  /// - Green accent
  /// - Standard navigation size
  /// - Standard highlight intensity
  /// - Filled cards
  /// - Rounded corners
  ///
  /// The storage entry is removed so that
  /// future launches use the same defaults.
  Future<void> restoreDefaults() {
    return _update(TruckLinkAppearanceSettings.defaults, clearStorage: true);
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  @override
  void dispose() {
    _isDisposed = true;

    super.dispose();
  }
}
