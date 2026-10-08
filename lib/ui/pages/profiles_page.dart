import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../state/models.dart';
import '../widgets/common.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Подписки',
          subtitle: 'Ссылки на подписку, Clash YAML или ключи vless / vmess / trojan / ss / hy2 / tuic',
          actions: [
            FilledButton.icon(
              onPressed: () => showAddProfileDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить'),
            ),
          ],
        ),
        Expanded(
          child: state.profiles.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(32, 4, 32, 32),
                  itemCount: state.profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => StaggeredEntrance(
                    key: ValueKey(state.profiles[i].id),
                    index: i,
                    child: _ProfileTile(
                      profile: state.profiles[i],
                      active: state.profiles[i].id == state.activeProfile?.id,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: StaggeredEntrance(
        index: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                ),
                shape: const StarBorder(
                  points: 10,
                  innerRadiusRatio: 0.84,
                  pointRounding: 0.6,
                  valleyRounding: 0.4,
                ),
              ),
              child: Icon(
                Icons.layers_rounded,
                size: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('Пока пусто', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Вставьте ссылку от вашего VPN-провайдера',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => showAddProfileDialog(context),
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Добавить подписку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, required this.active});
  final Profile profile;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final pr = profile;
    final host = pr.url == null
        ? 'Локальный список'
        : Uri.tryParse(pr.url!)?.host ?? pr.url!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active
            ? scheme.secondaryContainer.withValues(alpha: 0.9)
            : scheme.surfaceContainerLow.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(active ? 32 : 24),
        border: Border.all(
          color: active
              ? scheme.secondary
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: active ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(active ? 32 : 24),
          onTap: () => state.setActiveProfile(pr),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    active
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    key: ValueKey(active),
                    color: active ? scheme.secondary : scheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.name,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$host · ${pr.proxyCount} серверов · ${timeAgo(pr.updatedAt)}',
                        style: t.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (pr.usage != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: pr.usage,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${formatBytes(pr.used)} / ${formatBytes(pr.total)}',
                              style: t.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (pr.isRemote)
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: () async {
                      try {
                        await state.updateProfile(pr);
                        if (context.mounted) {
                          showSnack(context, 'Подписка обновлена');
                        }
                      } catch (e) {
                        if (context.mounted) showSnack(context, 'Ошибка: $e');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name = await _prompt(context, 'Название', pr.name);
                      if (name != null && name.trim().isNotEmpty) {
                        await state.renameProfile(pr, name.trim());
                      }
                    } else if (v == 'copy' && pr.url != null) {
                      await Clipboard.setData(ClipboardData(text: pr.url!));
                      if (context.mounted) {
                        showSnack(context, 'Ссылка скопирована');
                      }
                    } else if (v == 'delete') {
                      await state.deleteProfile(pr);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Переименовать'),
                    ),
                    if (pr.url != null)
                      const PopupMenuItem(
                        value: 'copy',
                        child: Text('Скопировать ссылку'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Удалить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _prompt(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<void> showAddProfileDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'add',
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, _) => const _AddDialog(),
    transitionBuilder: (context, anim, _, child) {
      final curve = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _input = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _input.text = data!.text!.trim());
  }

  Future<void> _submit() async {
    if (_input.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).addProfile(
        _input.text,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.add_link_rounded, color: scheme.primary, size: 32),
      title: const Text('Новая подписка'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _input,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'https://… или vless://…, по одной ссылке на строку',
                suffixIcon: IconButton(
                  tooltip: 'Вставить',
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'Название (необязательно)',
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Добавить'),
          ),
        ),
      ],
    );
  }
}
