import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/models.dart';
import '../widgets/common.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String _filter = 'all';

  bool _match(LogEntry e) => switch (_filter) {
    'warning' => e.level == 'warning' || e.level == 'error',
    'error' => e.level == 'error',
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Журнал',
          subtitle: 'Что происходит внутри ядра mihomo',
          actions: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Все')),
                ButtonSegment(value: 'warning', label: Text('Важные')),
                ButtonSegment(value: 'error', label: Text('Ошибки')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Очистить',
              onPressed: state.logs.clear,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final profile = state.activeProfile;
              final profileCard = GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.layers_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Подписка', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                          Text(
                            profile?.name ?? 'Не добавлена',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (profile != null)
                            Text(
                              '${profile.proxyCount} серверов · обновлена ${timeAgo(profile.updatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              final speedCard = GlassCard(
                padding: const EdgeInsets.all(16),
                child: ListenableBuilder(
                  listenable: state.traffic,
                  builder: (context, _) {
                    final tr = state.traffic;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Скорость', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TrafficValue(
                                icon: Icons.south_rounded,
                                label: 'Входящая',
                                speed: formatSpeed(tr.currentDown),
                                total: formatBytes(tr.totalDown),
                              ),
                            ),
                            Expanded(
                              child: _TrafficValue(
                                icon: Icons.north_rounded,
                                label: 'Исходящая',
                                speed: formatSpeed(tr.currentUp),
                                total: formatBytes(tr.totalUp),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              );
              return compact
                  ? Column(
                      children: [
                        profileCard,
                        const SizedBox(height: 12),
                        speedCard,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: profileCard),
                        const SizedBox(width: 12),
                        Expanded(child: speedCard),
                      ],
                    );
            },
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: state.logs,
              builder: (context, _) {
                final items = state.logs.entries
                    .where(_match)
                    .toList()
                    .reversed
                    .toList();
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Записей пока нет',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _LogLine(entry: items[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


class _TrafficValue extends StatelessWidget {
  const _TrafficValue({
    required this.icon,
    required this.label,
    required this.speed,
    required this.total,
  });

  final IconData icon;
  final String label;
  final String speed;
  final String total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(speed, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        Text('Всего $total', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (entry.level) {
      'error' => scheme.error,
      'warning' => const Color(0xFFE09000),
      'debug' => scheme.outline,
      _ => scheme.primary,
    };
    final time = entry.time;
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${two(time.hour)}:${two(time.minute)}:${two(time.second)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.level.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: SelectableText(
              entry.message,
              textWidthBasis: TextWidthBasis.parent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: ['Consolas'],
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
