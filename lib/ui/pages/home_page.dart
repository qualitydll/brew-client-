import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/models.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/public_ip_card.dart';
import '../widgets/traffic_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // A single home dashboard: widgets stay together rather than being split
  // into separate feature pages. The order can be changed by dragging.
  final List<String> _widgetOrder = ['start', 'routing', 'server', 'speed', 'ip', 'profile'];
  final Map<String, String> _widgetSizes = {};
  final Map<String, String> _widgetPairs = {};
  String? _note;
  bool _layoutLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_layoutLoaded) return;
    final settings = AppScope.of(context).settings;
    _widgetOrder
      ..clear()
      ..addAll(settings.homeWidgetOrder);
    _widgetSizes.addAll(settings.homeWidgetSizes);
    _widgetPairs.addAll(settings.homeWidgetPairs);
    _note = settings.homeWidgetNote;
    if (_note != null && !_widgetOrder.contains('note')) {
      _widgetOrder.add('note');
    }
    _layoutLoaded = true;
  }

  void _persistLayout() {
    final settings = AppScope.of(context).settings;
    settings.homeWidgetOrder = List<String>.from(_widgetOrder);
    settings.homeWidgetSizes = Map<String, String>.from(_widgetSizes);
    settings.homeWidgetPairs = Map<String, String>.from(_widgetPairs);
    settings.homeWidgetNote = _note;
  }

  void _manageWidget(String id, String action) {
    setState(() {
      if (action.startsWith('pair:')) {
        final target = action.substring(5);
        _widgetPairs.removeWhere((key, value) =>
            key == id || value == id || key == target || value == target);
        _widgetPairs[id] = target;
      } else if (action == 'unpair') {
        _widgetPairs.removeWhere((key, value) => key == id || value == id);
      } else if (action == 'remove') {
        _widgetOrder.remove(id);
        _widgetPairs.removeWhere((key, value) => key == id || value == id);
        _widgetSizes.remove(id);
        if (id == 'note') _note = null;
      } else if (action.startsWith('button-size:')) {
        AppScope.of(context).settings.homeButtonScale = action.substring(12);
      } else if (action.startsWith('button-align:')) {
        AppScope.of(context).settings.homeButtonAlignment = action.substring(13);
      } else {
        _widgetSizes[id] = action;
      }
      _persistLayout();
    });
  }

  Future<void> _addNote() async {
    final controller = TextEditingController(text: _note ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Текстовый блок'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Напишите что-нибудь…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() {
      _note = value.isEmpty ? null : value;
      if (_note != null && !_widgetOrder.contains('note')) {
        _widgetOrder.add('note');
      } else if (_note == null) {
        _widgetOrder.remove('note');
      }
      _persistLayout();
    });
  }

  void _addWidget(String id) {
    if (id == 'note') {
      _addNote();
      return;
    }
    if (_widgetOrder.contains(id)) {
      showSnack(context, 'Этот виджет уже добавлен');
      return;
    }
    setState(() {
      _widgetOrder.add(id);
      _persistLayout();
    });
  }

  Widget _startWidget(AppState state) {
    final settings = state.settings;
    final scale = settings.homeButtonScale;
    final width = switch (scale) {
      'small' => 148.0,
      'large' => 264.0,
      _ => 196.0,
    };
    final height = switch (scale) {
      'small' => 44.0,
      'large' => 62.0,
      _ => 52.0,
    };
    final alignment = switch (settings.homeButtonAlignment) {
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(Icons.power_settings_new_rounded, 'Кнопка подключения'),
          const SizedBox(height: 16),
          Align(
            alignment: alignment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: width,
                height: height,
                child: FilledButton.icon(
                  onPressed: state.profiles.isNotEmpty && !state.isBusy ? state.toggle : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: state.isBusy
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(state.isConnected ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      switch (state.status) {
                        ConnStatus.connecting => 'Подключение…',
                        ConnStatus.disconnecting => 'Отключение…',
                        ConnStatus.connected => 'Остановить',
                        ConnStatus.disconnected => 'Пуск',
                      },
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (state.isConnected && state.connectedAt != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.timer_outlined, size: 17, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 7),
              _Uptime(since: state.connectedAt!),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _routingWidget(AppState state) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(Icons.alt_route_rounded, 'Режим маршрутизации'),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'rule', label: Text('Умный'), icon: Icon(Icons.alt_route_rounded)),
              ButtonSegment(value: 'global', label: Text('Весь трафик'), icon: Icon(Icons.language_rounded)),
              ButtonSegment(value: 'direct', label: Text('Напрямую'), icon: Icon(Icons.trending_flat_rounded)),
            ],
            selected: {state.settings.mode},
            onSelectionChanged: (value) => state.setMode(value.first),
            showSelectedIcon: false,
            multiSelectionEnabled: false,
          ),
        ],
      ),
    );
  }

  Widget _trafficWidget(AppState state) {
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes Б';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
    }
    return GlassCard(
      child: ListenableBuilder(
        listenable: state.traffic,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(Icons.swap_vert_rounded, 'Трафик за сессию'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _TrafficValue(
                icon: Icons.arrow_downward_rounded,
                label: 'Получено',
                value: formatBytes(state.traffic.totalDown),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TrafficValue(
                icon: Icons.arrow_upward_rounded,
                label: 'Отправлено',
                value: formatBytes(state.traffic.totalUp),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sessionWidget(AppState state) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(Icons.timer_outlined, 'Сессия'),
          const SizedBox(height: 10),
          Text(
            state.isConnected && state.connectedAt != null
                ? 'Подключено'
                : 'Нет активной сессии',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.isConnected && state.connectedAt != null) ...[
            const SizedBox(height: 6),
            _Uptime(since: state.connectedAt!),
          ],
        ],
      ),
    );
  }

  Widget? _widgetFor(String id, AppState state) => switch (id) {
    'start' => _startWidget(state),
    'routing' => _routingWidget(state),
    'server' => _ServerCard(key: const ValueKey('server'), state: state),
    'speed' => _SpeedCard(key: const ValueKey('speed'), state: state),
    'ip' => const PublicIpCard(key: ValueKey('ip')),
    'profile' => _ProfileCard(key: const ValueKey('profile'), state: state),
    'traffic' => _trafficWidget(state),
    'session' => _sessionWidget(state),
    'connections' => state.isConnected
        ? _ConnectionsCard(key: const ValueKey('connections'), state: state)
        : null,
    'note' => _note == null
        ? null
        : GlassCard(
            key: const ValueKey('note'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.notes_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Заметка')),
                  IconButton(
                    tooltip: 'Изменить текст',
                    onPressed: _addNote,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Удалить виджет',
                    onPressed: () => setState(() {
                      _widgetOrder.remove('note');
                      _note = null;
                      _persistLayout();
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ]),
                Text(_note!),
              ],
            ),
          ),
    _ => null,
  };

  Widget _dashboardEntry(String id, AppState state, int index, List<String> ids) {
    final pairedId = _widgetPairs[id];
    final primary = _widgetFor(id, state) ?? const SizedBox.shrink();
    final paired = pairedId == null ? null : _widgetFor(pairedId, state);
    final canPair = _widgetOrder.where((other) =>
      other != id &&
      !_widgetPairs.values.contains(other) &&
      !_widgetPairs.containsKey(other) &&
      (other != 'connections' || state.isConnected)
    ).toList();
    return Padding(
      key: ValueKey('dashboard-$id'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: paired != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: primary),
                      const SizedBox(width: 10),
                      Expanded(child: paired),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: switch (_widgetSizes[id] ?? 'large') {
                          'small' => 360,
                          'medium' => 620,
                          _ => double.infinity,
                        },
                      ),
                      child: primary,
                    ),
                  ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Настроить виджет',
            onSelected: (action) => _manageWidget(id, action),
            icon: const Icon(Icons.tune_rounded, size: 19),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'small', child: Text('Маленький размер')),
              const PopupMenuItem(value: 'medium', child: Text('Средний размер')),
              const PopupMenuItem(value: 'large', child: Text('Большой размер')),
              if (id == 'start') ...[
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'button-size:small', child: Text('Кнопка: маленькая')),
                const PopupMenuItem(value: 'button-size:medium', child: Text('Кнопка: средняя')),
                const PopupMenuItem(value: 'button-size:large', child: Text('Кнопка: большая')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'button-align:left', child: Text('Кнопка слева')),
                const PopupMenuItem(value: 'button-align:center', child: Text('Кнопка по центру')),
                const PopupMenuItem(value: 'button-align:right', child: Text('Кнопка справа')),
              ],
              if (canPair.isNotEmpty) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(enabled: false, child: Text('Соединить с…')),
                for (final other in canPair)
                  PopupMenuItem(value: 'pair:$other', child: Text(_widgetLabel(other))),
              ],
              if (pairedId != null || _widgetPairs.values.contains(id))
                const PopupMenuItem(value: 'unpair', child: Text('Разъединить виджеты')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'remove', child: Text('Удалить виджет')),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, left: 2),
              child: Icon(Icons.drag_indicator_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  String _widgetLabel(String id) => switch (id) {
    'start' => 'Кнопка подключения',
    'routing' => 'Маршрутизация',
    'server' => 'Сервер',
    'speed' => 'Скорость',
    'ip' => 'Публичный IP',
    'profile' => 'Профиль',
    'traffic' => 'Трафик',
    'session' => 'Время сессии',
    'connections' => 'Соединения',
    'note' => 'Текстовый блок',
    _ => id,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 520 ? 16.0 : 28.0;
    final visibleOrder = _widgetOrder.where((id) => id != 'connections' || state.isConnected).toList();
    final ids = visibleOrder.where((id) => !_widgetPairs.values.contains(id)).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('brew', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  )),
                  const SizedBox(height: 3),
                  Text('Твоя сеть. Твои правила.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Добавить виджет',
              onSelected: _addWidget,
              icon: const Icon(Icons.add_rounded),
              itemBuilder: (context) => [
                if (!_widgetOrder.contains('start'))
                  const PopupMenuItem(value: 'start', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.power_settings_new_rounded),
                    title: Text('Кнопка подключения'),
                  )),
                if (!_widgetOrder.contains('routing'))
                  const PopupMenuItem(value: 'routing', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.alt_route_rounded),
                    title: Text('Маршрутизация'),
                  )),
                if (!_widgetOrder.contains('server'))
                  const PopupMenuItem(value: 'server', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.dns_rounded),
                    title: Text('Сервер'),
                  )),
                if (!_widgetOrder.contains('speed'))
                  const PopupMenuItem(value: 'speed', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.speed_rounded),
                    title: Text('Скорость'),
                  )),
                if (!_widgetOrder.contains('profile'))
                  const PopupMenuItem(value: 'profile', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.layers_rounded),
                    title: Text('Профиль'),
                  )),
                if (!_widgetOrder.contains('ip'))
                  const PopupMenuItem(value: 'ip', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.public_rounded),
                    title: Text('Публичный IP'),
                  )),
                if (!_widgetOrder.contains('connections'))
                  const PopupMenuItem(value: 'connections', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.alt_route_rounded),
                    title: Text('Соединения'),
                  )),
                if (!_widgetOrder.contains('traffic'))
                  const PopupMenuItem(value: 'traffic', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.swap_vert_rounded),
                    title: Text('Статистика трафика'),
                  )),
                if (!_widgetOrder.contains('session'))
                  const PopupMenuItem(value: 'session', child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.timer_outlined),
                    title: Text('Время сессии'),
                  )),
                const PopupMenuItem(value: 'note', child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notes_rounded),
                  title: Text('Текстовый блок'),
                )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Hero(state: state),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Мои виджеты', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ))),
            Text('Зажми и перетащи', style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ],
        ),
        const SizedBox(height: 10),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final item = ids.removeAt(oldIndex);
              ids.insert(newIndex, item);
              _widgetOrder
                ..clear()
                ..addAll([
                  for (final root in ids) ...[
                    root,
                    if (_widgetPairs[root] != null) _widgetPairs[root]!,
                  ],
                ]);
              _persistLayout();
            });
          },
          children: [
            for (var i = 0; i < ids.length; i++)
              _dashboardEntry(ids[i], state, i, ids),
          ],
        ),
        if (state.error != null || state.skipped.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ErrorBanner(state: state),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state});
  final AppState state;

  (String, String) get _texts => switch (state.status) {
    ConnStatus.disconnected => state.profiles.isEmpty
        ? ('Добро пожаловать', 'Добавьте подписку, чтобы начать')
        : ('Не защищено', 'Готово к подключению'),
    ConnStatus.connecting => ('Подключение…', 'Запускаем ядро mihomo'),
    ConnStatus.disconnecting => ('Отключение…', 'Завершаем сессию'),
    ConnStatus.connected => ('Защищено', 'Соединение активно'),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (title, subtitle) = _texts;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (state.isConnected ? scheme.primary : scheme.outlineVariant)
              .withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isConnected
                  ? scheme.primary
                  : state.isBusy
                      ? scheme.tertiary
                      : scheme.outline,
              boxShadow: state.isConnected
                  ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 12)]
                  : const [],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(title, key: ValueKey(title),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w750,
                      color: state.isConnected ? scheme.primary : scheme.onSurface,
                    )),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
          if (state.isConnected && state.connectedAt != null)
            _Uptime(since: state.connectedAt!),
        ],
      ),
    );
  }
}

class _TrafficValue extends StatelessWidget {
  const _TrafficValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ))),
        ]),
        const SizedBox(height: 5),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        )),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = state.error != null;
    final bg = isError ? scheme.errorContainer : scheme.tertiaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onTertiaryContainer;
    final n = state.skipped.length;
    final text =
        state.error ??
        'Пропущено серверов: $n — ядро не смогло их загрузить.\n${state.skipped.join('\n')}';
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isError
              ? Icon(Icons.error_outline_rounded, color: fg)
              : Icon(Icons.info_outline_rounded, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg),
            ),
          ),
          IconButton(
            onPressed: state.clearError,
            icon: Icon(Icons.close_rounded, color: fg, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Uptime extends StatefulWidget {
  const _Uptime({required this.since});
  final DateTime since;

  @override
  State<_Uptime> createState() => _UptimeState();
}

class _UptimeState extends State<_Uptime> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      formatDuration(DateTime.now().difference(widget.since)),
      style: t.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.icon, this.text, {this.trailing});
  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _ServerCard extends StatefulWidget {
  const _ServerCard({super.key, required this.state});
  final AppState state;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool _finding = false;
  bool _checking = false;

  Future<void> _best() async {
    setState(() => _finding = true);
    final best = await widget.state.selectBest();
    if (!mounted) return;
    setState(() => _finding = false);
    showSnack(
      context,
      best == null
          ? 'Не удалось найти рабочий сервер'
          : 'Выбран самый быстрый: $best',
    );
  }

  Future<void> _checkReachability() async {
    setState(() => _checking = true);
    final message = await widget.state.checkProfileReachability();
    if (!mounted) return;
    setState(() => _checking = false);
    showSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final server = state.currentServer;
    final chain = state.currentChain;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            Icons.dns_rounded,
            'Сервер',
            trailing: server == null
                ? null
                : PingChip(
                    delay: state.delays[server],
                    testing: state.testing.contains(server),
                  ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Column(
              key: ValueKey(server),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server ??
                      (state.isConnected
                          ? 'Не выбран'
                          : 'Подключитесь, чтобы выбрать'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (chain.length > 2)
                  Text(
                    chain.sublist(0, chain.length - 1).join('  →  '),
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: state.isConnected && !_finding ? _best : null,
                icon: _finding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Самый быстрый'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: state.isConnected
                    ? () => Shell.go(context, 1)
                    : state.isBusy ||
                          state.profiles.isEmpty ||
                          _checking ||
                          state.probingProfile
                    ? null
                    : _checkReachability,
                child: Text(
                  state.isConnected
                      ? 'Все серверы'
                      : _checking || state.probingProfile
                      ? 'Проверяем…'
                      : 'Проверить порты',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: ListenableBuilder(
        listenable: state.traffic,
        builder: (context, _) {
          final tr = state.traffic;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(Icons.speed_rounded, 'Скорость'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.south_rounded,
                      color: scheme.primary,
                      value: tr.currentDown.toDouble(),
                      total: tr.totalDown,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      icon: Icons.north_rounded,
                      color: scheme.tertiary,
                      value: tr.currentUp.toDouble(),
                      total: tr.totalUp,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 110, child: TrafficChart(store: tr)),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionsCard extends StatelessWidget {
  const _ConnectionsCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final connections = state.activeConnections.take(5).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            Icons.alt_route_rounded,
            'Активные соединения · ${state.activeConnections.length}',
            trailing: IconButton(
              tooltip: 'Обновить соединения',
              onPressed: state.refreshConnections,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          if (connections.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.connectionsError == null
                    ? 'Пока нет активных соединений'
                    : 'Ошибка Mihomo API: ${state.connectionsError}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final connection in connections)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      connection.network == 'udp'
                          ? Icons.swap_vert_rounded
                          : Icons.compare_arrows_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connection.port.isEmpty
                                ? connection.host
                                : '${connection.host}:${connection.port}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [
                              if (connection.rule.isNotEmpty)
                                '${connection.rule}${connection.rulePayload.isEmpty ? '' : ' · ${connection.rulePayload}'}',
                              if (connection.chains.isNotEmpty)
                                connection.chains.join(' → ')
                              else
                                'Маршрут не указан',
                            ].join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (connections.isNotEmpty && state.activeConnections.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Показаны первые 5 из ${state.activeConnections.length}',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.total,
  });
  final IconData icon;
  final Color color;
  final double value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                formatSpeed(v),
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              'всего ${formatBytes(total)}',
              style: t.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final pr = state.activeProfile;
    return GlassCard(
      onTap: () => Shell.go(context, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(Icons.layers_rounded, 'Подписка'),
          const SizedBox(height: 12),
          if (pr == null)
            Text('Нет подписок', style: t.titleMedium)
          else ...[
            Text(
              pr.name,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${pr.proxyCount} серверов',
                'обновлено ${timeAgo(pr.updatedAt)}',
                if (pr.expire != null)
                  'до ${pr.expire!.day}.${pr.expire!.month}.${pr.expire!.year}',
                if (!pr.hasExpiryInfo) 'срок не передан',
                if (!pr.hasTrafficInfo) 'лимит не передан',
              ].join(' · '),
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (_subscriptionWarning(pr) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _subscriptionWarning(pr)!,
                  style: t.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            if (pr.usage != null) ...[
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pr.usage!),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatBytes(pr.used)} из ${formatBytes(pr.total)}',
                style: t.bodySmall,
              ),
            ],
            if (pr.isRemote)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: state.busyProfile
                      ? null
                      : () async {
                          try {
                            await state.updateProfile(pr);
                            if (context.mounted) {
                              showSnack(context, 'Подписка обновлена');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showSnack(context, 'Не удалось обновить: $e');
                            }
                          }
                        },
                  icon: state.busyProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Обновить'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String? _subscriptionWarning(Profile profile) {
    final expire = profile.expire;
    if (expire != null && expire.isBefore(DateTime.now())) {
      return 'Срок подписки истёк';
    }
    if (expire != null && expire.difference(DateTime.now()).inDays < 7) {
      return 'Срок подписки скоро истечёт';
    }
    if (profile.total > 0 && profile.usage != null && profile.usage! >= 0.9) {
      return 'Использовано не менее 90% доступного трафика';
    }
    return null;
  }
}
