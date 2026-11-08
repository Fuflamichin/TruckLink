import 'package:network_protocol/finance_protocol.dart';

import '../jobs/history/job_history_entry.dart';

// ============================================
// TRUCKLINK ANALYTICS v0.8.3
// ============================================

enum AnalyticsPeriod { last7Days, last30Days, last90Days, allTime }

extension AnalyticsPeriodInfo on AnalyticsPeriod {
  String get title => switch (this) {
    AnalyticsPeriod.last7Days => '7 дней',
    AnalyticsPeriod.last30Days => '30 дней',
    AnalyticsPeriod.last90Days => '90 дней',
    AnalyticsPeriod.allTime => 'Всё время',
  };

  String get chartDescription => switch (this) {
    AnalyticsPeriod.last7Days => 'По дням',
    AnalyticsPeriod.last30Days => 'По 5 дней',
    AnalyticsPeriod.last90Days => 'По 15 дней',
    AnalyticsPeriod.allTime => 'Последние 6 месяцев',
  };
}

// ============================================
// RANKING ITEM
// ============================================

class AnalyticsRank {
  const AnalyticsRank({required this.name, required this.count});

  final String name;
  final int count;
}

// ============================================
// FINANCE TREND POINT
// ============================================

class AnalyticsTrendPoint {
  const AnalyticsTrendPoint({
    required this.label,
    required this.income,
    required this.expenses,
    required this.deliveries,
  });

  final String label;
  final int income;
  final int expenses;
  final int deliveries;

  int get net => income - expenses;
}

// ============================================
// AGGREGATED SUMMARY
// ============================================

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.gameId,
    required this.period,
    required this.deliveredCount,
    required this.cancelledCount,
    required this.plannedDistanceKm,
    required this.promisedRewards,
    required this.recordedIncome,
    required this.recordedExpenses,
    required this.recordedNet,
    required this.financeEventCount,
    required this.topDestinations,
    required this.topRoutes,
    required this.trend,
  });

  final int gameId;
  final AnalyticsPeriod period;

  final int deliveredCount;
  final int cancelledCount;

  /// Planned distance of delivered jobs.
  /// This is NOT actual distance driven.
  final int plannedDistanceKm;

  /// Contract reward of delivered jobs.
  /// This is NOT confirmed money received.
  final int promisedRewards;

  /// Actual finance events received by TruckLink.
  final int recordedIncome;
  final int recordedExpenses;
  final int recordedNet;
  final int financeEventCount;

  final List<AnalyticsRank> topDestinations;
  final List<AnalyticsRank> topRoutes;

  final List<AnalyticsTrendPoint> trend;

  int get totalJobs => deliveredCount + cancelledCount;

  double get completionPercent {
    if (totalJobs == 0) return 0;

    return deliveredCount / totalJobs * 100;
  }

  int get averagePlannedDistanceKm {
    if (deliveredCount == 0) return 0;

    return (plannedDistanceKm / deliveredCount).round();
  }

  bool get hasData => totalJobs > 0 || financeEventCount > 0;
}

// ============================================
// INTERNAL TREND BUCKET
// ============================================

class _TrendBucket {
  _TrendBucket({required this.start, required this.end, required this.label});

  final DateTime start;
  final DateTime end;
  final String label;

  int income = 0;
  int expenses = 0;
  int deliveries = 0;

  bool contains(DateTime localDate) {
    return !localDate.isBefore(start) && localDate.isBefore(end);
  }

  AnalyticsTrendPoint toPoint() {
    return AnalyticsTrendPoint(
      label: label,
      income: income,
      expenses: expenses,
      deliveries: deliveries,
    );
  }
}

// ============================================
// ANALYTICS CALCULATOR
// ============================================

abstract final class TruckLinkAnalytics {
  static const List<String> _monthNames = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  // ==========================================
  // CALCULATE
  // ==========================================

  static AnalyticsSummary calculate({
    required int gameId,
    required AnalyticsPeriod period,
    required List<JobHistoryEntry> jobs,
    required List<FinanceEvent> finances,
    DateTime? now,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();

    final startDate = _periodStart(period, localNow);

    // ========================================
    // FILTER BY GAME AND PERIOD
    // ========================================

    final selectedJobs = jobs
        .where((entry) {
          if (entry.job.gameId != gameId) {
            return false;
          }

          if (startDate == null) {
            return true;
          }

          return !entry.completedAtUtc.toLocal().isBefore(startDate);
        })
        .toList(growable: false);

    final selectedFinances = finances
        .where((event) {
          if (event.gameId != gameId) {
            return false;
          }

          if (startDate == null) {
            return true;
          }

          return !event.occurredAtUtc.toLocal().isBefore(startDate);
        })
        .toList(growable: false);

    // ========================================
    // DELIVERY STATISTICS
    // ========================================

    var delivered = 0;
    var cancelled = 0;

    var plannedDistance = 0;
    var promisedRewards = 0;

    final destinations = <String, int>{};
    final routes = <String, int>{};

    for (final entry in selectedJobs) {
      if (entry.isCancelled) {
        cancelled++;
        continue;
      }

      if (!entry.isDelivered) {
        continue;
      }

      delivered++;

      final job = entry.job;

      if (job.plannedDistanceKm > 0) {
        plannedDistance += job.plannedDistanceKm;
      }

      if (job.income > 0) {
        promisedRewards += job.income;
      }

      final source = job.sourceCity.trim();
      final destination = job.destinationCity.trim();

      if (destination.isNotEmpty) {
        destinations.update(
          destination,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      if (source.isNotEmpty && destination.isNotEmpty) {
        final route = '$source → $destination';

        routes.update(route, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    // ========================================
    // FINANCIAL STATISTICS
    // ========================================

    var income = 0;
    var expenses = 0;
    var net = 0;

    for (final event in selectedFinances) {
      net += event.amount;

      if (event.amount > 0) {
        income += event.amount;
      } else if (event.amount < 0) {
        expenses += -event.amount;
      }
    }

    // ========================================
    // TREND
    // ========================================

    final buckets = _createTrendBuckets(period, localNow);

    for (final entry in selectedJobs) {
      if (!entry.isDelivered) {
        continue;
      }

      final localDate = entry.completedAtUtc.toLocal();

      for (final bucket in buckets) {
        if (bucket.contains(localDate)) {
          bucket.deliveries++;
          break;
        }
      }
    }

    for (final event in selectedFinances) {
      final localDate = event.occurredAtUtc.toLocal();

      for (final bucket in buckets) {
        if (!bucket.contains(localDate)) {
          continue;
        }

        if (event.amount > 0) {
          bucket.income += event.amount;
        } else if (event.amount < 0) {
          bucket.expenses += -event.amount;
        }

        break;
      }
    }

    return AnalyticsSummary(
      gameId: gameId,
      period: period,
      deliveredCount: delivered,
      cancelledCount: cancelled,
      plannedDistanceKm: plannedDistance,
      promisedRewards: promisedRewards,
      recordedIncome: income,
      recordedExpenses: expenses,
      recordedNet: net,
      financeEventCount: selectedFinances.length,
      topDestinations: _topRankings(destinations),
      topRoutes: _topRankings(routes),
      trend: buckets.map((bucket) => bucket.toPoint()).toList(growable: false),
    );
  }

  // ==========================================
  // DATE FILTER
  // ==========================================

  static DateTime? _periodStart(AnalyticsPeriod period, DateTime now) {
    final days = switch (period) {
      AnalyticsPeriod.last7Days => 7,
      AnalyticsPeriod.last30Days => 30,
      AnalyticsPeriod.last90Days => 90,
      AnalyticsPeriod.allTime => null,
    };

    if (days == null) {
      return null;
    }

    // Inclusive of today.
    // Use local midnight, not rolling hours.
    return DateTime(now.year, now.month, now.day - days + 1);
  }

  // ==========================================
  // BUILD TREND BUCKETS
  // ==========================================

  static List<_TrendBucket> _createTrendBuckets(
    AnalyticsPeriod period,
    DateTime now,
  ) {
    if (period == AnalyticsPeriod.allTime) {
      // "All time" applies to summary statistics.
      // Its chart intentionally shows only
      // the six most recent calendar months.
      return List<_TrendBucket>.generate(6, (index) {
        final start = DateTime(now.year, now.month - 5 + index);

        final end = DateTime(start.year, start.month + 1);

        return _TrendBucket(
          start: start,
          end: end,
          label:
              '${_monthNames[start.month - 1]} '
              '${start.year}',
        );
      });
    }

    final totalDays = switch (period) {
      AnalyticsPeriod.last7Days => 7,
      AnalyticsPeriod.last30Days => 30,
      AnalyticsPeriod.last90Days => 90,
      AnalyticsPeriod.allTime => 30,
    };

    final daysPerBucket = switch (period) {
      AnalyticsPeriod.last7Days => 1,
      AnalyticsPeriod.last30Days => 5,
      AnalyticsPeriod.last90Days => 15,
      AnalyticsPeriod.allTime => 5,
    };

    final count = totalDays ~/ daysPerBucket;

    final firstDay = DateTime(now.year, now.month, now.day - totalDays + 1);

    return List<_TrendBucket>.generate(count, (index) {
      final start = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day + index * daysPerBucket,
      );

      final end = DateTime(start.year, start.month, start.day + daysPerBucket);

      final label = daysPerBucket == 1
          ? '${start.day} '
                '${_monthNames[start.month - 1]}'
          : '${_shortDay(start)}–'
                '${_shortDay(end.subtract(const Duration(days: 1)))}';

      return _TrendBucket(start: start, end: end, label: label);
    });
  }

  // ==========================================
  // RANKINGS
  // ==========================================

  static List<AnalyticsRank> _topRankings(Map<String, int> values) {
    final sorted = values.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);

        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return sorted
        .take(5)
        .map((entry) => AnalyticsRank(name: entry.key, count: entry.value))
        .toList(growable: false);
  }

  // ==========================================
  // FORMAT SHORT DAY
  // ==========================================

  static String _shortDay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month';
  }
}
