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
              softWrap: true,
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
