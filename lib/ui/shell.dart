import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import 'pages/home_page.dart';
import 'pages/logs_page.dart';
import 'pages/profiles_page.dart';
import 'pages/servers_page.dart';
import 'pages/settings_page.dart';
import 'widgets/aurora_background.dart';
import 'widgets/brew_mark.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  static void go(BuildContext context, int index) =>
      context.findAncestorStateOfType<_ShellState>()?._select(index);

  @override
  State<Shell> createState() => _ShellState();
}

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _dests = [
  _Dest('Главная', Icons.bolt_outlined, Icons.bolt_rounded),
  _Dest('Серверы', Icons.public_outlined, Icons.public_rounded),
  _Dest('Подписки', Icons.layers_outlined, Icons.layers_rounded),
  _Dest('Журнал', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Dest('Настройки', Icons.tune_outlined, Icons.tune_rounded),
];

class _ShellState extends State<Shell> {
  int _index = 0;
  bool _reverse = false;

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _reverse = i < _index;
      _index = i;
    });
  }

  Widget _page() => switch (_index) {
    0 => const HomePage(),
    1 => const ServersPage(),
    2 => const ProfilesPage(),
    3 => const LogsPage(),
    _ => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final content = PageTransitionSwitcher(
      duration: const Duration(milliseconds: 480),
      reverse: _reverse,
      transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
        animation: primary,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.vertical,
        fillColor: Colors.transparent,
        child: child,
      ),
      child: KeyedSubtree(key: ValueKey(_index), child: _page()),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _dests)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AuroraBackground(energized: state.isConnected),
          ),
          Column(
            children: [
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                const _TitleBar(),
              Expanded(
                child: Row(
                  children: [
                    if (wide)
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: _select,
                        groupAlignment: -0.85,
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 24, top: 4),
                          child: _Logo(status: state.status),
                        ),
                        destinations: [
                          for (final d in _dests)
                            NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                        ],
                      ),
                    Expanded(child: SafeArea(child: content)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.status});
  final ConnStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = status == ConnStatus.connected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      width: 48,
      height: 48,
      decoration: ShapeDecoration(
        shape: on
            ? const CircleBorder()
            : const StarBorder(
                points: 8,
                innerRadiusRatio: 0.82,
                pointRounding: 0.6,
                valleyRounding: 0.4,
              ),
        gradient: LinearGradient(
          colors: on
              ? [scheme.primary, scheme.tertiary]
              : [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/brew_logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: BrewMark(
                  size: 19,
                  lit: AppScope.of(context).isConnected,
                ),
              ),
            ),
          ),
          _WinButton(icon: Icons.remove_rounded, onTap: windowManager.minimize),
          _WinButton(
            icon: Icons.crop_square_rounded,
            onTap: () async => await windowManager.isMaximized()
                ? windowManager.unmaximize()
                : windowManager.maximize(),
          ),
          _WinButton(
            icon: Icons.close_rounded,
            onTap: windowManager.close,
            danger: true,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _WinButton extends StatefulWidget {
  const _WinButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = _hover
        ? (widget.danger ? scheme.error : scheme.surfaceContainerHighest)
        : Colors.transparent;
    final fg = _hover && widget.danger
        ? scheme.onError
        : scheme.onSurfaceVariant;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          width: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_hover ? 10 : 20),
          ),
          child: Icon(widget.icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
