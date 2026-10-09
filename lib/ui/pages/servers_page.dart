import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/models.dart';
import '../widgets/common.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final group = state.nodes[state.viewGroup];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Серверы',
          subtitle: group == null
              ? null
              : '${proxyTypeLabel(group.type)} · ${group.all.length} вариантов',
          actions: [
            if (group != null) ...[
              IconButton.filledTonal(
                tooltip: 'Проверить пинг',
                onPressed: () => state.testGroup(group.name),
                icon: const Icon(Icons.network_ping_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final best = await state.selectBest();
                  if (context.mounted) {
                    showSnack(
                      context,
                      best == null ? 'Нет доступных серверов' : 'Выбран: $best',
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Самый быстрый'),
              ),
            ],
          ],
        ),
        if (!state.isConnected)
          const Expanded(child: _NotConnected())
        else ...[
          if (state.groups.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in state.groups)
                    ChoiceChip(
                      label: Text(g.name),
                      selected: g.name == state.viewGroup,
                      onSelected: (_) => state.setViewGroup(g.name),
                    ),
                ],
              ),
            ),
          if (group != null)
            Expanded(
              child: _Grid(state: state, group: group),
            ),
        ],
      ],
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: StaggeredEntrance(
        index: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: ShapeDecoration(
                color: scheme.secondaryContainer,
                shape: const StarBorder(
                  points: 6,
                  innerRadiusRatio: 0.8,
                  pointRounding: 0.6,
                  valleyRounding: 0.4,
                ),
              ),
              child: Icon(
                Icons.public_off_rounded,
                size: 40,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Подключитесь, чтобы увидеть серверы',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: state.profiles.isEmpty || state.probingProfile
                      ? null
                      : () async {
                          final message =
                              await state.checkProfileReachability();
                          if (context.mounted) showSnack(context, message);
                        },
                  icon: state.probingProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: Text(
                    state.probingProfile
                        ? 'Проверяем порты…'
                        : 'Проверить доступность',
                  ),
                ),
                FilledButton(
                  onPressed: state.profiles.isEmpty || state.isBusy
                      ? null
                      : state.connect,
                  child: const Text('Подключиться'),
                ),
              ],
            ),
            if (state.reachabilityMessage != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 420,
                child: Text(
                  state.reachabilityMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.state, required this.group});
  final AppState state;
  final ProxyNode group;

  @override
  Widget build(BuildContext context) {
    final recent = state.recentServerNames;
    final members = [...group.all]
      ..sort((a, b) {
        final favoriteOrder =
            (state.isFavoriteServer(b) ? 1 : 0) -
            (state.isFavoriteServer(a) ? 1 : 0);
        if (favoriteOrder != 0) return favoriteOrder;
        final aRecent = recent.indexOf(a);
        final bRecent = recent.indexOf(b);
        final aRank = aRecent < 0 ? recent.length : aRecent;
        final bRank = bRecent < 0 ? recent.length : bRecent;
        return aRank.compareTo(bRank);
      });
    return GridView.builder(
      key: PageStorageKey(group.name),
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: 92,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final name = members[i];
        final node = state.nodes[name];
        return StaggeredEntrance(
          key: ValueKey('${group.name}/$name'),
          index: i,
          child: _ServerTile(
            name: name,
            type: node?.type ?? '',
            isGroup: node?.isGroup ?? false,
            selected: group.now == name,
            favorite: state.isFavoriteServer(name),
            recent: recent.contains(name),
            delay: state.delays[name],
            testing: state.testing.contains(name),
            onTap: group.isSelectable
                ? () => state.select(group.name, name)
                : null,
            onPing: () => state.testDelay(name),
            onToggleFavorite: () => state.toggleFavoriteServer(name),
          ),
        );
      },
    );
  }
}

class _ServerTile extends StatefulWidget {
  const _ServerTile({
    required this.name,
    required this.type,
    required this.isGroup,
    required this.selected,
    required this.favorite,
    required this.recent,
    required this.delay,
    required this.testing,
    required this.onTap,
    required this.onPing,
    required this.onToggleFavorite,
  });

  final String name;
  final String type;
  final bool isGroup;
  final bool selected;
  final bool favorite;
  final bool recent;
  final int? delay;
  final bool testing;
  final VoidCallback? onTap;
  final VoidCallback onPing;
  final VoidCallback onToggleFavorite;

  @override
  State<_ServerTile> createState() => _ServerTileState();
}

class _ServerTileState extends State<_ServerTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final sel = widget.selected;
    final fg = sel ? scheme.onPrimaryContainer : scheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: widget.onPing,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: sel
                ? scheme.primaryContainer
                : (_hover
                          ? scheme.surfaceContainerHigh
                          : scheme.surfaceContainerLow)
                      .withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(sel ? 36 : 20),
            border: Border.all(
              color: sel
                  ? scheme.primary.withValues(alpha: 0.5)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
              width: sel ? 2 : 1,
            ),
            boxShadow: [
              if (sel || _hover)
                BoxShadow(
                  color: scheme.primary.withValues(alpha: sel ? 0.22 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                width: 42,
                height: 42,
                decoration: ShapeDecoration(
                  color: sel ? scheme.primary : scheme.secondaryContainer,
                  shape: sel
                      ? const StarBorder(
                          points: 7,
                          innerRadiusRatio: 0.78,
                          pointRounding: 0.6,
                          valleyRounding: 0.4,
                        )
                      : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                ),
                child: Icon(
                  sel
                      ? Icons.check_rounded
                      : (widget.isGroup
                            ? Icons.folder_rounded
                            : Icons.public_rounded),
                  color: sel ? scheme.onPrimary : scheme.onSecondaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      proxyTypeLabel(widget.type),
                      style: t.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isGroup)
                GestureDetector(
                  onTap: widget.onPing,
                  child: PingChip(delay: widget.delay, testing: widget.testing),
                ),
              if (!widget.isGroup)
                if (widget.recent && !widget.favorite)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: scheme.outline,
                    ),
                  ),
              if (!widget.isGroup)
                IconButton(
                  tooltip: widget.favorite
                      ? 'Убрать из избранного'
                      : 'Добавить в избранное',
                  onPressed: widget.onToggleFavorite,
                  icon: Icon(
                    widget.favorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: widget.favorite ? scheme.primary : scheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
