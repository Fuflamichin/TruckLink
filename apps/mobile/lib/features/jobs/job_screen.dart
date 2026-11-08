import 'package:flutter/material.dart';
import 'package:network_protocol/job_lifecycle_protocol.dart';
import 'package:telemetry_core/job_telemetry.dart';

import '../../core/network/telemetry_connection.dart';
import 'history/job_history_screen.dart';

// ============================================
// TRUCKLINK JOB SCREEN v0.8.4
// ============================================

class JobScreen extends StatelessWidget {
  const JobScreen({super.key, required this.connection});

  final TelemetryConnection connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) {
        return _buildContent(context);
      },
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const JobHistoryScreen()));
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    final TruckLinkJobTelemetry? job =
        connection.isConnected && connection.hasLiveData
        ? connection.activeJob
        : null;

    // ========================================
    // BOTTOM NAVIGATION INSET
    // ========================================

    // AppShell uses Scaffold.extendBody = true.
    // MediaQuery.padding.bottom already includes
    // the actual floating navigation height.
    //
    // Do not add an additional fixed 210px.
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24.0;

    return ListView(
      key: const PageStorageKey<String>('trucklink-job-screen'),
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      children: [
        // ====================================
        // HEADER
        // ====================================
        Row(
          children: [
            Expanded(
              child: Text(
                'Текущая перевозка',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            if (job != null) ...[
              const SizedBox(width: 8),
              const _JobBadge(label: 'Выполняется', icon: Icons.circle),
            ],

            const SizedBox(width: 4),

            IconButton(
              tooltip: 'История перевозок',
              onPressed: () => _openHistory(context),
              icon: const Icon(Icons.history_rounded),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ====================================
        // DISCONNECTED
        // ====================================
        if (!connection.isConnected)
          _JobEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Нет подключения к Hub',
            description:
                'Подключи телефон к TruckLink Hub '
                'на компьютере, чтобы получать '
                'данные о перевозках.',
            details: connection.statusMessage,
          )
        // ====================================
        // ACTIVE JOB
        // ====================================
        else if (job != null) ...[
          _CargoCard(job: job),

          const SizedBox(height: 12),

          _RouteCard(job: job),

          const SizedBox(height: 18),

          Text(
            'Информация о рейсе',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          _JobMetrics(job: job),

          // There must be only a normal gap
          // between the metrics and details.
          const SizedBox(height: 12),

          _AdditionalJobDetails(job: job),

          const SizedBox(height: 14),

          Text(
            'Расстояние и ETA поступают '
            'из игрового навигатора. '
            'Срок доставки указан '
            'в игровом времени.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ]
        // ====================================
        // DELIVERED
        // ====================================
        else if (connection.lastJobEvent == JobLifecycleEventKind.delivered)
          const _JobEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Доставка завершена',
            description:
                'Груз успешно доставлен. '
                'Можешь принять следующий заказ '
                'в ETS2 или ATS.',
            details:
                'Результат получен от игрового '
                'плагина. Запись можно '
                'посмотреть в истории.',
            isSuccess: true,
          )
        // ====================================
        // CANCELLED
        // ====================================
        else if (connection.lastJobEvent == JobLifecycleEventKind.cancelled)
          const _JobEmptyState(
            icon: Icons.cancel_outlined,
            title: 'Заказ отменён',
            description:
                'Перевозка была отменена. '
                'Выбери новый заказ в игре.',
            details:
                'Отмена подтверждена '
                'игровым плагином.',
            isWarning: true,
          )
        // ====================================
        // WAITING FOR GAME DATA
        // ====================================
        else if (!connection.hasLiveData)
          _JobEmptyState(
            icon: Icons.sports_esports_outlined,
            title: 'Ожидание данных игры',
            description:
                'Подключение к Windows Hub '
                'есть, но ETS2 / ATS пока '
                'не отправляет актуальные '
                'данные грузовика.',
            details: connection.statusMessage,
          )
        // ====================================
        // NO ACTIVE JOB
        // ====================================
        else
          const _JobEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Нет активного заказа',
            description:
                'Прими перевозку в Euro Truck '
                'Simulator 2 или American Truck '
                'Simulator. Данные о грузе '
                'появятся автоматически.',
            details: 'Телеметрия грузовика подключена.',
          ),
      ],
    );
  }
}

// ============================================
// JOB STATUS BADGE
// ============================================

class _JobBadge extends StatelessWidget {
  const _JobBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 9),

          const SizedBox(width: 7),

          Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// EMPTY / RESULT STATE
// ============================================

class _JobEmptyState extends StatelessWidget {
  const _JobEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
    this.isSuccess = false,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String details;

  final bool isSuccess;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final accent = isWarning ? scheme.error : scheme.primary;

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
                fontWeight: FontWeight.w800,
                color: isSuccess ? accent : null,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),

                const SizedBox(width: 8),

                Flexible(
                  child: Text(
                    details,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
    final scheme = theme.colorScheme;

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
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                    color: scheme.primary,
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
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
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

            const Divider(),

            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 9,
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

  static String _display(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? 'Не указано' : trimmed;
  }

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
                Icon(Icons.route_rounded, size: 21, color: accent),

                const SizedBox(width: 9),

                Text(
                  'Маршрут',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ==================================
            // STATIC ROUTE CONNECTION
            // ==================================

            // This line connects origin and
            // destination visually.
            //
            // It is NOT a progress indicator.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 25,
                    child: Column(
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          size: 22,
                          color: accent,
                        ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.60),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),

                        Icon(
                          Icons.location_on_rounded,
                          size: 23,
                          color: accent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RouteLocation(
                          label: 'ОТКУДА',
                          city: _display(job.sourceCity),
                          company: _display(job.sourceCompany),
                        ),

                        const SizedBox(height: 39),

                        _RouteLocation(
                          label: 'КУДА',
                          city: _display(job.destinationCity),
                          company: _display(job.destinationCompany),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ROUTE LOCATION
// ============================================

class _RouteLocation extends StatelessWidget {
  const _RouteLocation({
    required this.label,
    required this.city,
    required this.company,
  });

  final String label;
  final String city;
  final String company;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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

        const SizedBox(height: 5),

        Text(
          city,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          company,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ============================================
// JOB METRICS
// ============================================

class _JobMetrics extends StatelessWidget {
  const _JobMetrics({required this.job});

  final TruckLinkJobTelemetry job;

  @override
  Widget build(BuildContext context) {
    final distance = job.navigationDistanceKm;
    final mass = job.cargoMassKg;

    final stats = <_JobStat>[
      _JobStat(
        title: 'Награда',
        value: _JobFormat.groupNumber(job.income),
        note: 'В валюте игры',
        icon: Icons.payments_outlined,
      ),

      _JobStat(
        title: 'Весь маршрут',
        value: job.plannedDistanceKm > 0
            ? '${_JobFormat.groupNumber(job.plannedDistanceKm)} км'
            : '—',
        note: 'Плановое расстояние',
        icon: Icons.route_outlined,
      ),

      _JobStat(
        title: 'Осталось',
        value: distance != null && distance.isFinite && distance > 0
            ? '${distance.toStringAsFixed(1)} км'
            : '—',
        note: 'По игровому GPS',
        icon: Icons.navigation_outlined,
      ),

      _JobStat(
        title: 'Время в пути',
        value: _JobFormat.durationFromSeconds(job.navigationTimeSeconds),
        note: 'Оценка навигатора',
        icon: Icons.timer_outlined,
      ),

      _JobStat(
        title: 'До сдачи',
        value: _JobFormat.gameMinutes(job.remainingDeliveryMinutes),
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
        final columns = constraints.maxWidth < 300 ? 1 : 2;

        return GridView.builder(
          // ==================================
          // FIX v0.8.4
          // ==================================
          //
          // This GridView is nested inside
          // the parent ListView.
          //
          // Without explicit zero padding,
          // GridView adds MediaQuery padding,
          // which includes the floating
          // navigation height and creates
          // a large empty gap below the cards.
          //
          // Only the parent ListView should
          // handle navigation clearance.
          padding: EdgeInsets.zero,
          primary: false,

          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),

          itemCount: stats.length,

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 126,
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
// JOB STAT MODEL
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
// JOB STAT CARD
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
              value: job.cargoLoaded ? 'Загружен' : 'Загрузка не подтверждена',
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

            if (job.specialJob) ...[
              const Divider(height: 19),

              const _DetailRow(label: 'Тип перевозки', value: 'Особая'),
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
// FORMATTING
// ============================================

abstract final class _JobFormat {
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

    final result = buffer.toString();

    return negative ? '-$result' : result;
  }

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
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours ч';
    }

    return '$hours ч $remaining мин';
  }

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
