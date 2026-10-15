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
  final List<String> _widgetOrder = ['server', 'speed', 'ip', 'profile'];
  final Map<String, String> _widgetSizes = {};
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
    settings.homeWidgetNote = _note;
  }

  void _manageWidget(String id, String action) {
    setState(() {
      if (action == 'remove') {
        _widgetOrder.remove(id);
        if (id == 'note') _note = null;
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

  Widget? _widgetFor(String id, AppState state) => switch (id) {
    'server' => _ServerCard(key: const ValueKey('server'), state: state),
    'speed' => _SpeedCard(key: const ValueKey('speed'), state: state),
    'ip' => const PublicIpCard(key: ValueKey('ip')),
    'profile' => _ProfileCard(key: const ValueKey('profile'), state: state),
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 520 ? 16.0 : 28.0;
    final ids = _widgetOrder.where((id) => id != 'connections' || state.isConnected).toList();
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
                ..addAll(ids);
              _persistLayout();
            });
          },
          children: [
            for (var i = 0; i < ids.length; i++)
              Padding(
                key: ValueKey('dashboard-${ids[i]}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: switch (_widgetSizes[ids[i]] ?? 'large') {
                              'small' => 360,
                              'medium' => 620,
                              _ => double.infinity,
                            },
                          ),
                          child: _widgetFor(ids[i], state) ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Настроить виджет',
                      onSelected: (action) => _manageWidget(ids[i], action),
                      icon: const Icon(Icons.tune_rounded, size: 19),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'small', child: Text('Маленький размер')),
                        PopupMenuItem(value: 'medium', child: Text('Средний размер')),
                        PopupMenuItem(value: 'large', child: Text('Большой размер')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'remove', child: Text('Удалить виджет')),
                      ],
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, left: 2),
                        child: Icon(Icons.drag_indicator_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
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
    ConnStatus.disconnected =>
      state.profiles.isEmpty
          ? ('Добро пожаловать', 'Добавьте подписку, чтобы начать')
          : ('Не защищено', 'Нажмите, чтобы подключиться'),
    ConnStatus.connecting => ('Подключение…', 'Запускаем ядро mihomo'),
    ConnStatus.disconnecting => ('Отключение…', 'Возвращаем прямое соединение'),
    ConnStatus.connected => ('Защищено', ''),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (title, subtitle) = _texts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: state.profiles.isNotEmpty && !state.isBusy ? state.toggle : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(196, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: state.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(state.isConnected ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(
            switch (state.status) {
              ConnStatus.connecting => 'Подключение…',
              ConnStatus.disconnecting => 'Отключение…',
              ConnStatus.connected => 'Остановить',
              ConnStatus.disconnected => 'Пуск',
            },
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
              child: child,
            ),
          ),
          child: Text(
            title,
            key: ValueKey(title),
            style: t.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: state.isConnected ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 24,
          child: state.isConnected && state.connectedAt != null
              ? _Uptime(since: state.connectedAt!)
              : Text(
                  subtitle,
                  style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
        ),
        const SizedBox(height: 28),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'rule',
              label: Text('Умный'),
              icon: Icon(Icons.alt_route_rounded),
            ),
            ButtonSegment(
              value: 'global',
              label: Text('Весь трафик'),
              icon: Icon(Icons.language_rounded),
            ),
            ButtonSegment(
              value: 'direct',
              label: Text('Напрямую'),
              icon: Icon(Icons.trending_flat_rounded),
            ),
          ],
          selected: {state.settings.mode},
          onSelectionChanged: (s) => state.setMode(s.first),
          showSelectedIcon: false,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: state.error == null && state.skipped.isEmpty
              ? const SizedBox(width: 420)
              : Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _ErrorBanner(state: state),
                ),
        ),
        if (state.profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton.icon(
              onPressed: () => Shell.go(context, 2),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить подписку'),
            ),
          ),
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
