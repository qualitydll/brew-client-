import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/models.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/connect_orb.dart';
import '../widgets/traffic_chart.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final hero = _Hero(state: state);
    final cards = [
      _ServerCard(state: state),
      _SpeedCard(state: state),
      _ProfileCard(state: state),
    ];
    if (wide) {
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: Center(child: SingleChildScrollView(child: hero)),
          ),
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 32, 32),
              children: [
                for (var i = 0; i < cards.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StaggeredEntrance(index: i + 1, child: cards[i]),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        hero,
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: StaggeredEntrance(index: i + 1, child: cards[i]),
          ),
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
          ? ('добро пожаловать', 'добавьте подписку, чтобы начать')
          : ('не защищено', 'нажмите, чтобы подключиться'),
    ConnStatus.connecting => ('подключение…', 'запускаем ядро mihomo'),
    ConnStatus.disconnecting => ('отключение…', 'возвращаем прямое соединение'),
    ConnStatus.connected => ('защищено', ''),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (title, subtitle) = _texts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConnectOrb(
          status: state.status,
          enabled: state.profiles.isNotEmpty,
          onTap: state.toggle,
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
              label: Text('умный'),
              icon: Icon(Icons.alt_route_rounded),
            ),
            ButtonSegment(
              value: 'global',
              label: Text('весь трафик'),
              icon: Icon(Icons.language_rounded),
            ),
            ButtonSegment(
              value: 'direct',
              label: Text('напрямую'),
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
              label: const Text('добавить подписку'),
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
        'пропущено серверов: $n — ядро не смогло их загрузить.\n${state.skipped.join('\n')}';
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
  const _ServerCard({required this.state});
  final AppState state;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool _finding = false;

  Future<void> _best() async {
    setState(() => _finding = true);
    final best = await widget.state.selectBest();
    if (!mounted) return;
    setState(() => _finding = false);
    showSnack(
      context,
      best == null
          ? 'не удалось найти рабочий сервер'
          : 'выбран самый быстрый: $best',
    );
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
            'сервер',
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
                          ? 'не выбран'
                          : 'подключитесь, чтобы выбрать'),
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
                label: const Text('самый быстрый'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: state.isConnected
                    ? () => Shell.go(context, 1)
                    : null,
                child: const Text('все серверы'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.state});
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
              const _CardTitle(Icons.speed_rounded, 'скорость'),
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
  const _ProfileCard({required this.state});
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
          const _CardTitle(Icons.layers_rounded, 'подписка'),
          const SizedBox(height: 12),
          if (pr == null)
            Text('нет подписок', style: t.titleMedium)
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
              ].join(' · '),
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
          ],
        ],
      ),
    );
  }
}
