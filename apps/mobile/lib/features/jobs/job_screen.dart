import 'package:flutter/material.dart';
import 'package:telemetry_core/job_telemetry.dart';

import '../../core/network/telemetry_connection.dart';

// ============================================
// TRUCKLINK JOB SCREEN
// Version 0.7.3
// ============================================

class JobScreen extends StatelessWidget {
  const JobScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        return _buildContent(context);
      },
    );
  }

  // ==========================================
  // CONTENT
  // ==========================================

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final bottomPadding = MediaQuery.paddingOf(context).bottom + 28.0;

    // ========================================
    // DETERMINE CURRENT STATE
    // ========================================

    final bool hubConnected = connection.isConnected;
    final bool telemetryLive = connection.hasLiveData;

    final TruckLinkJobTelemetry? job = hubConnected && telemetryLive
        ? connection.activeJob
        : null;

    return ListView(
      key: const PageStorageKey<String>('trucklink-job-screen'),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      children: [
        // ====================================
        // PAGE HEADER
        // ====================================
        Row(
          children: [
            Expanded(
              child: Text(
                'Текущая перевозка',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (job != null)
              _StatusBadge(
                label: 'Выполняется',
                color: accent,
                icon: Icons.circle,
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // NO HUB CONNECTION
        // ====================================
        if (!hubConnected) ...[
          _JobEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Нет подключения к Hub',
            description:
                'Подключи телефон к TruckLink Hub '
                'на компьютере, чтобы получать '
                'данные о перевозках.',
            details: connection.statusMessage,
          ),
        ]
        // ====================================
        // NO LIVE TELEMETRY
        // ====================================
        else if (!telemetryLive) ...[
          _JobEmptyState(
            icon: Icons.sports_esports_outlined,
            title: 'Ожидание данных игры',
            description:
                'Соединение с Windows Hub установлено, '
                'но телеметрия ETS2 / ATS '
                'пока не поступает.',
            details: connection.statusMessage,
          ),
        ]
        // ====================================
        // NO ACTIVE JOB
        // ====================================
        else if (job == null) ...[
          const _JobEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Нет активного заказа',
            description:
                'Прими перевозку в Euro Truck '
                'Simulator 2 или American Truck '
                'Simulator. Информация о грузе '
                'и маршруте появится автоматически.',
            details: 'Телеметрия грузовика подключена.',
          ),
        ]
        // ====================================
        // ACTIVE REAL JOB
        // ====================================
        else ...[
          // ================================
          // CARGO CARD
          // ================================
          _CargoCard(job: job),

          const SizedBox(height: 12),

          // ================================
          // ROUTE CARD
          // ================================
          _RouteCard(job: job),

          const SizedBox(height: 18),

          // ================================
          // KEY METRICS
          // ================================
          Text(
            'Информация о рейсе',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          _JobMetrics(job: job),

          const SizedBox(height: 12),

          // ================================
          // ADDITIONAL INFORMATION
          // ================================
          _AdditionalJobDetails(job: job),

          const SizedBox(height: 14),

          Text(
            'Расстояние и ETA берутся из '
            'игрового навигатора. '
            'Срок доставки указан '
            'в игровом времени.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================
// STATUS BADGE
// ============================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 9),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// EMPTY JOB STATE
// ============================================

class _JobEmptyState extends StatelessWidget {
  const _JobEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String description;
  final String details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 35, color: accent),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, color: muted, size: 17),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    details,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// CARGO CARD
// ============================================

class _CargoCard extends StatelessWidget {
  const _CargoCard({required this.job});

  final TruckLinkJobTelemetry job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    final mass = job.cargoMassKg;

    final massText = mass != null && mass.isFinite && mass > 0
        ? '${(mass / 1000).toStringAsFixed(1)} т'
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ГРУЗ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.displayCargo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Divider(color: theme.dividerColor.withValues(alpha: 0.55)),

            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InlineDetail(
                  icon: Icons.sports_esports_outlined,
                  value: job.gameName,
                ),
                if (massText != null)
                  _InlineDetail(icon: Icons.scale_outlined, value: massText),
                if (job.specialJob)
                  const _InlineDetail(
                    icon: Icons.star_outline_rounded,
                    value: 'Особая перевозка',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// INLINE DETAIL
// ============================================

class _InlineDetail extends StatelessWidget {
  const _InlineDetail({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ============================================
// ROUTE CARD
// ============================================

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.job});

  final TruckLinkJobTelemetry job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: accent, size: 21),
                const SizedBox(width: 9),
                Text(
                  'Маршрут',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _RoutePoint(
              icon: Icons.radio_button_checked,
              label: 'ОТКУДА',
              city: _displayText(job.sourceCity),
              company: _displayText(job.sourceCompany),
              color: accent,
            ),

            Padding(
              padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
              child: Container(
                height: 30,
                width: 2,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            _RoutePoint(
              icon: Icons.location_on_rounded,
              label: 'КУДА',
              city: _displayText(job.destinationCity),
              company: _displayText(job.destinationCompany),
              color: accent,
            ),
          ],
        ),
      ),
    );
  }

  static String _displayText(String text) {
    final clean = text.trim();

    return clean.isEmpty ? 'Не указано' : clean;
  }
}

// ============================================
// ROUTE POINT
// ============================================

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.label,
    required this.city,
    required this.company,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String city;
  final String company;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 22, child: Icon(icon, color: color, size: 21)),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                city,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                company,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// JOB METRICS GRID
// ============================================

class _JobMetrics extends StatelessWidget {
  const _JobMetrics({required this.job});

  final TruckLinkJobTelemetry job;

  @override
  Widget build(BuildContext context) {
    final navigationDistance = job.navigationDistanceKm;

    final mass = job.cargoMassKg;

    final stats = <_JobStat>[
      _JobStat(
        title: 'Награда',
        value: _JobFormatting.groupNumber(job.income),
        note: 'В валюте игры',
        icon: Icons.payments_outlined,
      ),

      _JobStat(
        title: 'Весь маршрут',
        value: job.plannedDistanceKm > 0
            ? '${_JobFormatting.groupNumber(job.plannedDistanceKm)} км'
            : '—',
        note: 'Плановое расстояние',
        icon: Icons.route_outlined,
      ),

      _JobStat(
        title: 'Осталось',
        value:
            navigationDistance != null &&
                navigationDistance.isFinite &&
                navigationDistance > 0
            ? '${navigationDistance.toStringAsFixed(1)} км'
            : '—',
        note: 'По игровому GPS',
        icon: Icons.navigation_outlined,
      ),

      _JobStat(
        title: 'Время в пути',
        value: _JobFormatting.durationFromSeconds(job.navigationTimeSeconds),
        note: 'Оценка навигатора',
        icon: Icons.timer_outlined,
      ),

      _JobStat(
        title: 'До сдачи',
        value: _JobFormatting.gameMinutes(job.remainingDeliveryMinutes),
        note: 'Игровое время',
        icon: Icons.event_available_outlined,
      ),

      _JobStat(
        title: 'Масса груза',
        value: mass != null && mass.isFinite && mass > 0
            ? '${(mass / 1000).toStringAsFixed(1)} т'
            : '—',
        note: 'Общий вес',
        icon: Icons.scale_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 310 ? 1 : 2;

        final childRatio = columns == 1 ? 2.8 : 1.40;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childRatio,
          ),
          itemBuilder: (context, index) {
            return _JobStatCard(stat: stats[index]);
          },
        );
      },
    );
  }
}

// ============================================
// METRIC DATA
// ============================================

class _JobStat {
  const _JobStat({
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;
}

// ============================================
// METRIC CARD
// ============================================

class _JobStatCard extends StatelessWidget {
  const _JobStatCard({required this.stat});

  final _JobStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(stat.icon, size: 18, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    stat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  stat.value,
                  maxLines: 1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              stat.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ADDITIONAL JOB DETAILS
// ============================================

class _AdditionalJobDetails extends StatelessWidget {
  const _AdditionalJobDetails({required this.job});

  final TruckLinkJobTelemetry job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final damage = job.cargoDamagePercent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дополнительные сведения',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 13),

            _DetailRow(
              label: 'Состояние груза',
              value: job.cargoLoaded ? 'Загружен' : 'Не подтверждена загрузка',
            ),

            const Divider(height: 19),

            _DetailRow(
              label: 'Повреждения',
              value: damage != null && damage.isFinite && damage >= 0
                  ? '${damage.toStringAsFixed(1)} %'
                  : '—',
            ),

            if (job.unitCount > 0) ...[
              const Divider(height: 19),

              _DetailRow(label: 'Единиц груза', value: '${job.unitCount}'),
            ],

            if (job.jobMarket.trim().isNotEmpty) ...[
              const Divider(height: 19),

              _DetailRow(label: 'Тип заказа', value: job.jobMarket),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// DETAIL ROW
// ============================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// NUMBER AND TIME FORMATTING
// ============================================

abstract final class _JobFormatting {
  // ==========================================
  // GROUP THOUSANDS
  // ==========================================

  static String groupNumber(int number) {
    final negative = number < 0;
    final digits = number.abs().toString();

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(' ');
      }

      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();

    return negative ? '-$formatted' : formatted;
  }

  // ==========================================
  // NAVIGATION TIME
  // ==========================================

  static String durationFromSeconds(double? seconds) {
    if (seconds == null || !seconds.isFinite || seconds <= 0) {
      return '—';
    }

    final minutes = (seconds / 60).round();

    if (minutes <= 0) {
      return 'меньше 1 мин';
    }

    if (minutes < 60) {
      return '$minutes мин';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours ч';
    }

    return '$hours ч $remainingMinutes мин';
  }

  // ==========================================
  // IN-GAME DELIVERY TIME
  // ==========================================

  static String gameMinutes(int? minutes) {
    if (minutes == null || minutes < 0) {
      return '—';
    }

    if (minutes == 0) {
      return '0 мин';
    }

    final days = minutes ~/ 1440;
    final hours = (minutes % 1440) ~/ 60;
    final mins = minutes % 60;

    if (days > 0) {
      return hours == 0 ? '$days д' : '$days д $hours ч';
    }

    if (hours > 0) {
      return mins == 0 ? '$hours ч' : '$hours ч $mins мин';
    }

    return '$mins мин';
  }
}
