import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/system_proxy.dart';
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
        title: 'внешний вид',
        children: [
          _Row(
            title: 'тема',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('авто'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('светлая'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('тёмная'),
                ),
              ],
              selected: {s.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => state.setThemeMode(v.first),
            ),
          ),
          const SizedBox(height: 20),
          Text('цвет', style: Theme.of(context).textTheme.titleSmall),
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
          Text('стиль палитры', style: Theme.of(context).textTheme.titleSmall),
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
        title: 'подключение',
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('системный прокси'),
            subtitle: const Text(
              'браузеры и большинство программ пойдут через brew',
            ),
            value: s.systemProxy,
            onChanged: state.setSystemProxy,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('режим tun (весь трафик устройства)'),
            subtitle: Text(
              state.isAdmin
                  ? 'виртуальный сетевой адаптер — работают даже игры и мессенджеры'
                  : 'требуются права администратора',
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
                label: const Text('перезапустить от администратора'),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('разрешить подключения из локальной сети'),
            value: s.allowLan,
            onChanged: state.setAllowLan,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('порт прокси'),
            subtitle: Text('HTTP + SOCKS5 на 127.0.0.1:${s.mixedPort}'),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final v = await _prompt(context, 'порт прокси', '${s.mixedPort}');
              final port = int.tryParse(v ?? '');
              if (port != null && port > 0 && port < 65536) {
                await state.setMixedPort(port);
              }
            },
          ),
        ],
      ),
      _Section(
        icon: Icons.memory_rounded,
        title: 'ядро',
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('mihomo ${state.coreVersion ?? ''}'),
            subtitle: Text(
              state.corePath ?? 'не найдено — положите mihomo рядом с программой в папку core',
            ),
            trailing: const Icon(Icons.folder_open_rounded),
            onTap: () async {
              final v = await _prompt(
                context,
                'путь к mihomo',
                state.corePath ?? '',
              );
              if (v != null) {
                await state.setCorePath(v.trim().isEmpty ? null : v.trim());
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('папка данных'),
            subtitle: Text(state.dataDir),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () {
              Clipboard.setData(ClipboardData(text: state.dataDir));
              showSnack(context, 'путь скопирован');
            },
          ),
        ],
      ),
      const _Section(
        icon: Icons.info_rounded,
        title: 'о программе',
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
        const PageHeader(title: 'настройки'),
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
          child: const Text('отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('сохранить'),
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
      message: color == null ? 'цвет системы' : '',
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
