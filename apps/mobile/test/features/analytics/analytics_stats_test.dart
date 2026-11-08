import 'package:flutter_test/flutter_test.dart';
import 'package:network_protocol/finance_protocol.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';

import '../../../lib/features/analytics/analytics_stats.dart';
import '../../../lib/features/jobs/history/job_history_entry.dart';

// ============================================
// TEST DATA HELPERS
// ============================================

TruckLinkJobTelemetry makeJob({
  required int gameId,
  required String sourceCity,
  required String destinationCity,
  required int income,
  required int distanceKm,
}) {
  return TruckLinkJobTelemetry(
    gameId: gameId,
    cargoId: 'test_cargo',
    cargoName: 'Test Cargo',
    sourceCity: sourceCity,
    destinationCity: destinationCity,
    sourceCompany: 'Source Company',
    destinationCompany: 'Destination Company',
    jobMarket: 'freight_market',
    income: income,
    plannedDistanceKm: distanceKm,
    unitCount: 1,
    cargoLoaded: true,
    specialJob: false,
  );
}

JobHistoryEntry makeHistory({
  required String id,
  required int gameId,
  required JobLifecycleEventKind result,
  required DateTime localTime,
  required String source,
  required String destination,
  required int reward,
  required int distance,
}) {
  return JobHistoryEntry(
    id: id,
    result: result,
    completedAtUtc: localTime.toUtc(),
    job: makeJob(
      gameId: gameId,
      sourceCity: source,
      destinationCity: destination,
      income: reward,
      distanceKm: distance,
    ),
  );
}

FinanceEvent makeFinance({
  required String id,
  required int gameId,
  required FinanceEventKind kind,
  required int amount,
  required DateTime localTime,
}) {
  return FinanceEvent(
    id: id,
    gameId: gameId,
    kind: kind,
    amount: amount,
    occurredAtUtc: localTime.toUtc(),
  );
}

// ============================================
// TESTS
// ============================================

void main() {
  final now = DateTime(2026, 11, 8, 15);

  final jobs = <JobHistoryEntry>[
    makeHistory(
      id: 'ets-delivered',
      gameId: 1,
      result: JobLifecycleEventKind.delivered,
      localTime: DateTime(2026, 11, 7, 12),
      source: 'Berlin',
      destination: 'Paris',
      reward: 20000,
      distance: 1200,
    ),
    makeHistory(
      id: 'ets-cancelled',
      gameId: 1,
      result: JobLifecycleEventKind.cancelled,
      localTime: DateTime(2026, 11, 8, 11),
      source: 'Hamburg',
      destination: 'Prague',
      reward: 8000,
      distance: 700,
    ),
    makeHistory(
      id: 'ets-old',
      gameId: 1,
      result: JobLifecycleEventKind.delivered,
      localTime: DateTime(2026, 10, 1, 12),
      source: 'Berlin',
      destination: 'Paris',
      reward: 9000,
      distance: 600,
    ),
    makeHistory(
      id: 'ats-delivered',
      gameId: 2,
      result: JobLifecycleEventKind.delivered,
      localTime: DateTime(2026, 11, 8, 12),
      source: 'Los Angeles',
      destination: 'Las Vegas',
      reward: 50000,
      distance: 450,
    ),
  ];

  final finances = <FinanceEvent>[
    makeFinance(
      id: 'ets-income',
      gameId: 1,
      kind: FinanceEventKind.deliveredRevenue,
      amount: 15000,
      localTime: DateTime(2026, 11, 7, 12),
    ),
    makeFinance(
      id: 'ets-fine',
      gameId: 1,
      kind: FinanceEventKind.fine,
      amount: -500,
      localTime: DateTime(2026, 11, 8, 13),
    ),
    makeFinance(
      id: 'ets-old-income',
      gameId: 1,
      kind: FinanceEventKind.deliveredRevenue,
      amount: 7000,
      localTime: DateTime(2026, 10, 1, 12),
    ),
    makeFinance(
      id: 'ats-income',
      gameId: 2,
      kind: FinanceEventKind.deliveredRevenue,
      amount: 48000,
      localTime: DateTime(2026, 11, 8, 12),
    ),
  ];

  group('TruckLink analytics', () {
    test('Filters ETS2 and last 7 days', () {
      final summary = TruckLinkAnalytics.calculate(
        gameId: 1,
        period: AnalyticsPeriod.last7Days,
        jobs: jobs,
        finances: finances,
        now: now,
      );

      expect(summary.deliveredCount, 1);
      expect(summary.cancelledCount, 1);
      expect(summary.totalJobs, 2);

      expect(summary.completionPercent, 50);

      // Cancelled jobs must not contribute
      // to delivered planned distance.
      expect(summary.plannedDistanceKm, 1200);
      expect(summary.averagePlannedDistanceKm, 1200);

      expect(summary.promisedRewards, 20000);

      // Real revenue differs from the
      // promised contract reward.
      expect(summary.recordedIncome, 15000);
      expect(summary.recordedExpenses, 500);
      expect(summary.recordedNet, 14500);

      expect(summary.financeEventCount, 2);

      expect(summary.topDestinations.first.name, 'Paris');

      expect(summary.topDestinations.first.count, 1);
    });

    test('Does not mix ATS and ETS2', () {
      final summary = TruckLinkAnalytics.calculate(
        gameId: 2,
        period: AnalyticsPeriod.last30Days,
        jobs: jobs,
        finances: finances,
        now: now,
      );

      expect(summary.deliveredCount, 1);
      expect(summary.cancelledCount, 0);
      expect(summary.plannedDistanceKm, 450);

      expect(summary.promisedRewards, 50000);
      expect(summary.recordedIncome, 48000);
      expect(summary.recordedExpenses, 0);
      expect(summary.recordedNet, 48000);

      expect(summary.topDestinations.first.name, 'Las Vegas');
    });

    test('All-time includes older records', () {
      final summary = TruckLinkAnalytics.calculate(
        gameId: 1,
        period: AnalyticsPeriod.allTime,
        jobs: jobs,
        finances: finances,
        now: now,
      );

      expect(summary.deliveredCount, 2);
      expect(summary.cancelledCount, 1);
      expect(summary.totalJobs, 3);

      expect(summary.plannedDistanceKm, 1800);
      expect(summary.promisedRewards, 29000);

      expect(summary.recordedIncome, 22000);
      expect(summary.recordedExpenses, 500);
      expect(summary.recordedNet, 21500);

      expect(summary.topDestinations.first.count, 2);
    });

    test('Trend sums match selected period', () {
      final summary = TruckLinkAnalytics.calculate(
        gameId: 1,
        period: AnalyticsPeriod.last7Days,
        jobs: jobs,
        finances: finances,
        now: now,
      );

      expect(summary.trend, hasLength(7));

      final trendIncome = summary.trend.fold<int>(
        0,
        (total, point) => total + point.income,
      );

      final trendExpenses = summary.trend.fold<int>(
        0,
        (total, point) => total + point.expenses,
      );

      final trendDeliveries = summary.trend.fold<int>(
        0,
        (total, point) => total + point.deliveries,
      );

      expect(trendIncome, 15000);
      expect(trendExpenses, 500);
      expect(trendDeliveries, 1);
    });

    test('Empty history is handled safely', () {
      final summary = TruckLinkAnalytics.calculate(
        gameId: 1,
        period: AnalyticsPeriod.last30Days,
        jobs: const [],
        finances: const [],
        now: now,
      );

      expect(summary.hasData, isFalse);
      expect(summary.totalJobs, 0);
      expect(summary.completionPercent, 0);
      expect(summary.averagePlannedDistanceKm, 0);
      expect(summary.recordedNet, 0);
      expect(summary.topRoutes, isEmpty);
      expect(summary.topDestinations, isEmpty);
    });
  });
}
