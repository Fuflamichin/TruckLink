import 'dart:convert';

import 'network_protocol.dart' show protocolVersion;

const String financeEventMessageType = 'finance_event';

enum FinanceEventKind {
  deliveredRevenue,
  cancelledPenalty,
  fine,
  toll,
  ferry,
  train,
}

extension FinanceEventKindInfo on FinanceEventKind {
  String get title => switch (this) {
    FinanceEventKind.deliveredRevenue => 'Доход от доставки',
    FinanceEventKind.cancelledPenalty => 'Штраф за отмену',
    FinanceEventKind.fine => 'Дорожный штраф',
    FinanceEventKind.toll => 'Платная дорога',
    FinanceEventKind.ferry => 'Паром',
    FinanceEventKind.train => 'Поезд',
  };

  bool get isIncome => this == FinanceEventKind.deliveredRevenue;
}

class FinanceEvent {
  const FinanceEvent({
    required this.id,
    required this.gameId,
    required this.kind,
    required this.amount,
    required this.occurredAtUtc,
  });

  final String id;
  final int gameId;
  final FinanceEventKind kind;

  /// Signed amount in the game's own money units.
  ///
  /// Positive = income.
  /// Negative = expense.
  ///
  /// This is NOT the player's account balance.
  final int amount;

  final DateTime occurredAtUtc;

  String get gameName => switch (gameId) {
    1 => 'Euro Truck Simulator 2',
    2 => 'American Truck Simulator',
    _ => 'Unknown',
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameId': gameId,
      'kind': kind.name,
      'amount': amount,
      'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
    };
  }

  factory FinanceEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final gameId = json['gameId'];
    final kind = json['kind'];
    final amount = json['amount'];
    final timestamp = json['occurredAtUtc'];

    if (id is! String || id.trim().isEmpty || id.length > 160) {
      throw const FormatException('Invalid finance event ID');
    }

    if (gameId is! int || (gameId != 1 && gameId != 2)) {
      throw const FormatException('Invalid finance event game ID');
    }

    if (amount is! int) {
      throw const FormatException('Invalid finance amount');
    }

    final parsedKind = FinanceEventKind.values
        .where((value) => value.name == kind)
        .firstOrNull;

    if (parsedKind == null) {
      throw const FormatException('Unknown finance event kind');
    }

    if (timestamp is! String) {
      throw const FormatException('Missing finance event timestamp');
    }

    final date = DateTime.tryParse(timestamp);

    if (date == null) {
      throw const FormatException('Invalid finance event timestamp');
    }

    return FinanceEvent(
      id: id,
      gameId: gameId,
      kind: parsedKind,
      amount: amount,
      occurredAtUtc: date.toUtc(),
    );
  }
}

String encodeFinanceEvent(FinanceEvent event) {
  return jsonEncode({
    'version': protocolVersion,
    'type': financeEventMessageType,
    'payload': event.toJson(),
  });
}

bool isFinanceEventMessage(String message) {
  try {
    final decoded = jsonDecode(message);

    return decoded is Map<String, dynamic> &&
        decoded['type'] == financeEventMessageType;
  } on FormatException {
    return false;
  }
}

FinanceEvent decodeFinanceEvent(String message) {
  final decoded = jsonDecode(message);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid finance event envelope');
  }

  if (decoded['version'] != protocolVersion ||
      decoded['type'] != financeEventMessageType) {
    throw const FormatException('Unsupported finance event message');
  }

  final payload = decoded['payload'];

  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Invalid finance event payload');
  }

  return FinanceEvent.fromJson(payload);
}
