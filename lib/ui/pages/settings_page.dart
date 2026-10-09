import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/system_proxy.dart';
import '../../core/routing_rules.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.settings;
    final sections = <Widget>[
      _Section(
        icon: Icons.palette_rounded,
        title: 'Внешний вид',
        children: [
          _Row(
            title: 'Тема',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('Авто'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Светлая'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Тёмная'),
                ),
              ],
              selected: {s.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => state.setThemeMode(v.first),
            ),
          ),
          const SizedBox(height: 20),
          Text('Цвет', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Swatch(
                color: null,
                selected: s.systemColor,
                onTap: () => state.setSystemColor(true),
              ),
              for (final c in seedPalette)
                _Swatch(
                  color: c,
                  selected:
                      !s.systemColor && s.seedColor.toARGB32() == c.toARGB32(),
                  onTap: () => state.setSeed(c),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Стиль палитры', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in variantNames.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: s.schemeVariant == e.key,
                  onSelected: (_) => state.setVariant(e.key),
                ),
            ],
          ),
        ],
      ),
      _Section(
        icon: Icons.router_rounded,
        title: 'Подключение',
        children: [
          if (Platform.isAndroid)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Android VPN'),
              subtitle: Text('Весь трафик проходит через системный VpnService.'),
            )
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Системный прокси'),
              subtitle: const Text(
                'Браузеры и большинство программ пойдут через brew',
              ),
              value: s.systemProxy,
              onChanged: state.setSystemProxy,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Режим TUN (весь трафик устройства)'),
              subtitle: Text(
                state.isAdmin
                    ? 'Виртуальный сетевой адаптер — работают даже игры и мессенджеры'
                    : 'Требуются права администратора',
              ),
              value: s.tun,
              onChanged: state.setTun,
            ),
            if (s.tun && !state.isAdmin && Platform.isWindows)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await state.shutdown();
                    if (await Elevation.relaunchAsAdmin()) exit(0);
                  },
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: const Text('Перезапустить от администратора'),
                ),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Разрешить подключения из локальной сети'),
            value: s.allowLan,
            onChanged: state.setAllowLan,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Порт прокси'),
            subtitle: Text('HTTP + SOCKS5 на 127.0.0.1:${s.mixedPort}'),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final v = await _prompt(context, 'Порт прокси', '${s.mixedPort}');
              final port = int.tryParse(v ?? '');
              if (port != null && port > 0 && port < 65536) {
                await state.setMixedPort(port);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Маршрутизация доменов'),
            subtitle: Text(
              s.domainRules.isEmpty
                  ? 'Сайт → через группу, напрямую или блокировать'
                  : '${s.domainRules.length} правил — раньше правил подписки',
            ),
            trailing: const Icon(Icons.add_rounded),
            onTap: () async {
              try {
                final actions = await state.routingActionsForActiveProfile();
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (_) => _DomainRuleDialog(
                    actions: actions,
                    onSave: state.addDomainRule,
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  showSnack(context, 'Не удалось открыть правила: $e');
                }
              }
            },
          ),
          if (s.domainRules.isNotEmpty)
            for (final rule in s.domainRules)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 12),
                leading: const Icon(Icons.language_rounded),
                title: Text(rule),
                trailing: IconButton(
                  tooltip: 'Удалить правило',
                  onPressed: () => state.removeDomainRule(rule),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Правила вручную · Advanced'),
            subtitle: Text(
              s.userRules.trim().isEmpty
                  ? 'Дополнительные правила Mihomo отключены'
                  : '${s.userRules.split('\n').where((rule) => rule.trim().isNotEmpty).length} '
                        'строк — применяются раньше правил подписки',
            ),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final rules = await _promptMultiline(
                context,
                'Расширенные правила Mihomo',
                s.userRules,
              );
              if (rules != null) await state.setUserRules(rules);
            },
          ),
        ],
      ),
      _Section(
        icon: Icons.memory_rounded,
        title: 'Ядро',
        children: [
          if (Platform.isAndroid)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('mihomo ${state.coreVersion ?? ''}'),
              subtitle: const Text('Встроенное ядро, устанавливается вместе с приложением.'),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('mihomo ${state.coreVersion ?? ''}'),
              subtitle: Text(
                state.corePath ??
                    'Не найдено — положите mihomo рядом с программой в папку core',
              ),
              trailing: const Icon(Icons.folder_open_rounded),
              onTap: () async {
                final v = await _prompt(
                  context,
                  'Путь к mihomo',
                  state.corePath ?? '',
                );
                if (v != null) {
                  await state.setCorePath(v.trim().isEmpty ? null : v.trim());
                }
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Папка данных'),
            subtitle: Text(state.dataDir),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () {
              Clipboard.setData(ClipboardData(text: state.dataDir));
              showSnack(context, 'Путь скопирован');
            },
          ),
        ],
      ),
      const _Section(
        icon: Icons.info_rounded,
        title: 'О программе',
        children: [
          Text(
            'brew 0.1.0 — VPN-клиент на базе mihomo с дизайном Material You.',
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: 'Настройки'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, i) =>
                StaggeredEntrance(index: i, child: sections[i]),
          ),
        ),
      ],
    );
  }
}

class _DomainRuleDialog extends StatefulWidget {
  const _DomainRuleDialog({
    required this.actions,
    required this.onSave,
  });

  final List<String> actions;
  final Future<void> Function(String rule) onSave;

  @override
  State<_DomainRuleDialog> createState() => _DomainRuleDialogState();
}

class _DomainRuleDialogState extends State<_DomainRuleDialog> {
  final _domain = TextEditingController();
  late String _action = widget.actions.contains('PROXY')
      ? 'PROXY'
      : widget.actions.first;
  bool _includeSubdomains = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final rule = normalizeDomainRule(
        _domain.text,
        includeSubdomains: _includeSubdomains,
        action: _action,
        allowedActions: widget.actions,
      );
      await widget.onSave(rule);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message.toString());
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Маршрутизация сайта'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _domain,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Домен',
                hintText: 'example.com',
                helperText: 'Без https://, пути и параметров',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSubdomains,
              onChanged: (value) =>
                  setState(() => _includeSubdomains = value ?? false),
              title: const Text('Включая поддомены'),
              subtitle: const Text('Например, api.example.com'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _action,
              decoration: const InputDecoration(
                labelText: 'Действие',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final action in widget.actions)
                  DropdownMenuItem(value: action, child: Text(actionLabel(action))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

String actionLabel(String action) => switch (action) {
  'DIRECT' => 'Напрямую',
  'REJECT' => 'Блокировать',
  _ => 'Через $action',
};

Future<String?> _prompt(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
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

Future<String?> _promptMultiline(
  BuildContext context,
  String title,
  String initial,
) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: c,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'DOMAIN-SUFFIX,example.com,PROXY',
            helperText:
                'Одна Mihomo rule на строку. Они проверяются раньше правил подписки.',
            border: OutlineInputBorder(),
          ),
        ),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        child,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: color == null ? 'Цвет системы' : '',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: color,
              gradient: color == null
                  ? const SweepGradient(
                      colors: [
                        Color(0xFFEF5350),
                        Color(0xFFFFCA28),
                        Color(0xFF66BB6A),
                        Color(0xFF42A5F5),
                        Color(0xFFAB47BC),
                        Color(0xFFEF5350),
                      ],
                    )
                  : null,
              shape: selected
                  ? const StarBorder(
                      points: 8,
                      innerRadiusRatio: 0.84,
                      pointRounding: 0.6,
                      valleyRounding: 0.4,
                    )
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
              shadows: selected
                  ? [
                      BoxShadow(
                        color: (color ?? scheme.primary).withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey(1),
                      color: Colors.white,
                    )
                  : (color == null
                        ? const Icon(
                            Icons.auto_awesome_rounded,
                            key: ValueKey(2),
                            color: Colors.white,
                            size: 20,
                          )
                        : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
