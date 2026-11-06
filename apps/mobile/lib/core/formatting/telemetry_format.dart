/// Common telemetry value formatting for TruckLink.
///
/// All formatting happens only in the UI.
/// Original telemetry values are not modified.
abstract final class TelemetryFormat {
  static const String unavailable = '—';

  // ==========================================
  // WHOLE NUMBERS
  // ==========================================

  /// Rounds a number to the nearest integer.
  ///
  /// 82.7 -> 83
  /// 82.2 -> 82
  /// 100.0 -> 100
  ///
  /// null, NaN and infinity -> —
  static String integer(num? value, {bool absolute = false}) {
    if (value == null || !value.isFinite) {
      return unavailable;
    }

    final number = absolute ? value.abs() : value;

    return number.round().toString();
  }

  // ==========================================
  // UNITS
  // ==========================================

  static String withUnit(num? value, String unit, {bool absolute = false}) {
    final formatted = integer(value, absolute: absolute);

    if (formatted == unavailable) {
      return unavailable;
    }

    if (unit.isEmpty) {
      return formatted;
    }

    if (unit == '%') {
      return '$formatted%';
    }

    return '$formatted $unit';
  }

  // ==========================================
  // COMMON TELEMETRY
  // ==========================================

  static String speed(num? kmh) {
    return withUnit(kmh, 'км/ч', absolute: true);
  }

  static String rpm(num? value) {
    return withUnit(value, 'RPM');
  }

  static String temperature(num? celsius) {
    return withUnit(celsius, '°C');
  }

  static String percent(num? value) {
    return withUnit(value, '%');
  }

  static String distance(num? km) {
    return withUnit(km, 'км');
  }

  static String liters(num? value) {
    return withUnit(value, 'л');
  }

  // ==========================================
  // GEAR
  // ==========================================

  static String gear(int gear) {
    if (gear == 0) return 'N';

    if (gear < 0) {
      return 'R${gear.abs()}';
    }

    return gear.toString();
  }

  // ==========================================
  // SPEED LIMIT
  // ==========================================

  /// Zero or negative values mean that no
  /// valid limit is currently available.
  static String speedLimit(num? kmh) {
    if (kmh == null || !kmh.isFinite || kmh <= 0) {
      return unavailable;
    }

    return speed(kmh);
  }

  // ==========================================
  // CRUISE CONTROL
  // ==========================================

  static String cruiseControl(num? kmh) {
    if (kmh == null || !kmh.isFinite) {
      return unavailable;
    }

    if (kmh <= 0) {
      return 'Выключен';
    }

    return speed(kmh);
  }

  // ==========================================
  // FUEL TANK
  // ==========================================

  static String fuelTank(num? liters, num? capacity) {
    if (liters == null ||
        capacity == null ||
        !liters.isFinite ||
        !capacity.isFinite ||
        capacity <= 0) {
      return unavailable;
    }

    return '${integer(liters)} / '
        '${integer(capacity)} л';
  }

  // ==========================================
  // ON / OFF
  // ==========================================

  static String onOff(
    bool? value, {
    String enabled = 'Включён',
    String disabled = 'Выключен',
  }) {
    if (value == null) {
      return unavailable;
    }

    return value ? enabled : disabled;
  }
}
