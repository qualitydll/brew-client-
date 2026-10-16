import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/common.dart';

class ExperimentLabPage extends StatefulWidget {
  const ExperimentLabPage({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  State<ExperimentLabPage> createState() => _ExperimentLabPageState();
}

class _ExperimentLabPageState extends State<ExperimentLabPage> {
  bool _running = false;
  bool _selectingBest = false;
  String? _summary;
  List<_LabResult> _results = const [];

  Future<void> _runDiagnostics(AppState state) async {
    if (_running || state.isBusy) return;
    setState(() {
      _running = true;
      _summary = null;
      _results = const [];
    });

    try {
      final profile = state.activeProfile;
      if (profile == null) {
        _summary = 'Сначала добавьте подписку.';
        return;
      }

      if (!state.isConnected) {
        final message = await state.checkProfileReachability();
        _summary = message;
        _results = [
          for (final entry in state.reachability.entries)
            _LabResult(
              title: entry.key,
              detail: entry.value ? 'TCP-порт отвечает' : 'TCP-порт недоступен',
              ok: entry.value,
            ),
          const _LabResult(
            title: 'Ограничение проверки',
            detail:
                'Проверяется только доступность TCP-порта. Это не подтверждает '
                'работоспособность прокси-протокола или доступность интернета через VPN.',
          ),
        ];
        return;
      }

      await state.refreshProxies();
      final group = state.mainGroup;
      if (group == null) {
        _summary = 'Mihomo отвечает, но в активном профиле нет группы для проверки.';
        _results = const [
          _LabResult(title: 'Mihomo API', detail: 'Ответ получен', ok: true),
          _LabResult(
            title: 'Группа прокси',
            detail: 'Не найдена; проверьте конфигурацию подписки.',
            ok: false,
          ),
        ];
        return;
      }

      await state.testGroup(group.name);
      await state.refreshConnections();

      final candidates = group.all.where((name) {
        final node = state.nodes[name];
        return node != null &&
            !node.isGroup &&
            name != 'DIRECT' &&
            name != 'REJECT';
      }).toList();
      final measured = [
        for (final name in candidates)
          if ((state.delays[name] ?? -1) > 0) name,
      ];
      final current = state.currentChain;
      _summary = 'Проверка завершена через Mihomo. '
          'Рабочие по тестовому запросу узлы: ${measured.length} из ${candidates.length}.';
      _results = [
        const _LabResult(
          title: 'Mihomo API',
          detail: 'Ответ получен',
          ok: true,
        ),
        _LabResult(
          title: 'Группа',
          detail: group.name,
          ok: true,
        ),
        _LabResult(
          title: 'Узлы с успешным тестом задержки',
          detail: '${measured.length} из ${candidates.length}',
          ok: measured.isNotEmpty,
        ),
        _LabResult(
          title: 'Текущий маршрут',
          detail: current.isEmpty ? 'Не определён' : current.join(' → '),
          ok: current.isNotEmpty,
        ),
        _LabResult(
          title: 'Активные соединения',
          detail: '${state.activeConnections.length}',
          ok: state.connectionsError == null,
        ),
        const _LabResult(
          title: 'Ограничение проверки',
          detail:
              'Успешная задержка подтверждает только тестовый запрос Mihomo. '
              'Она не гарантирует доступ ко всем сайтам или работу в любой сети.',
        ),
      ];
    } catch (e) {
      _summary = 'Диагностика завершилась с ошибкой: $e';
      _results = const [
        _LabResult(
          title: 'Диагностика',
          detail: 'Не удалось завершить все проверки. Откройте журнал для подробностей.',
          ok: false,
        ),
      ];
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _selectBest(AppState state) async {
    if (_selectingBest || !state.isConnected) return;
    setState(() {
      _selectingBest = true;
      _summary = null;
    });
    try {
      final best = await state.selectBest();
      if (!mounted) return;
      setState(() {
        _summary = best == null
            ? 'Не найден узел с успешным тестом задержки. Текущий маршрут не изменён.'
            : 'Mihomo переключил группу на узел «$best».';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _summary = 'Не удалось выбрать узел: $e');
    } finally {
      if (mounted) setState(() => _selectingBest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        if (widget.showHeader)
          PageHeader(
            title: 'Brew Network Lab',
            subtitle: 'Адаптивная диагностика сети, прокси и маршрутов',
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.science_outlined, color: scheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Состояние сети',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        state.isConnected ? Icons.check_circle : Icons.info_outline,
                        size: 18,
                      ),
                      label: Text(state.isConnected ? 'Mihomo запущен' : 'VPN отключён'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.isConnected
                      ? 'Проверяем качество соединения через текущий Mihomo: задержку узлов, выбранный маршрут и активные соединения. Ядро и настройки профиля не меняются автоматически.'
                      : 'Если VPN отключён, проверяем доступность TCP-портов серверов из активной подписки. Это помогает локализовать сбой, но не подтверждает работу протокола.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _running || state.isBusy
                          ? null
                          : () => _runDiagnostics(state),
                      icon: _running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_running ? 'Проверяем…' : 'Проверить соединение'),
                    ),
                    OutlinedButton.icon(
                      onPressed: !state.isConnected || _selectingBest || _running
                          ? null
                          : () => _selectBest(state),
                      icon: _selectingBest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.speed_rounded),
                      label: Text(
                        _selectingBest ? 'Тестируем узлы…' : 'Выбрать лучший узел',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_summary != null)
          Card(
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_summary!),
            ),
          ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Результаты', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final result in _results)
            Card(
              child: ListTile(
                leading: Icon(
                  result.ok == null
                      ? Icons.info_outline_rounded
                      : result.ok!
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                  color: result.ok == null
                      ? scheme.onSurfaceVariant
                      : result.ok!
                          ? scheme.primary
                          : scheme.error,
                ),
                title: Text(result.title),
                subtitle: Text(result.detail),
                isThreeLine: result.detail.length > 90,
              ),
            ),
        ],
        const SizedBox(height: 16),
        Card(
          color: scheme.surfaceContainerLowest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Adaptive Network — экспериментальный слой диагностики Brew. Он помогает понять, на каком этапе возникает проблема, и выбрать узел по штатному тесту Mihomo. Результат проверки не гарантирует доступность каждого сайта; автоматическая смена конфигурации ядра отключена, чтобы не ломать профиль провайдера.',
            ),
          ),
        ),
      ],
    );
  }
}

class _LabResult {
  const _LabResult({required this.title, required this.detail, this.ok});

  final String title;
  final String detail;
  final bool? ok;
}
