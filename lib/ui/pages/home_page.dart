import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/models.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/connect_orb.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(compact ? 20 : 32, 24, compact ? 20 : 32, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Hero(state: state),
                  const SizedBox(height: 28),
                  _ServerCard(state: state),
                ],
              ),
            ),
          ),
        );
      },
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
          ? 'Не удалось найти рабочий сервер'
          : 'Выбран самый быстрый: $best',
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
                  server ?? state.settings.preferredServer ??
                      (state.profiles.isEmpty ? 'Добавьте подписку' : 'Сервер не выбран'),
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
              if (state.isConnected)
                FilledButton.tonalIcon(
                  onPressed: _finding ? null : _best,
                  icon: _finding
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Быстрый сервер'),
                ),
              if (state.isConnected) const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Shell.go(context, state.profiles.isEmpty ? 2 : 1),
                icon: Icon(state.profiles.isEmpty ? Icons.add_rounded : Icons.dns_rounded),
                label: Text(state.profiles.isEmpty ? 'Добавить подписку' : 'Выбрать сервер'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
