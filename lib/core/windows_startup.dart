import 'dart:io';

/// Manages Brew's per-user Windows login startup entry without admin rights.
class WindowsStartup {
  WindowsStartup._();

  static const _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Brew';

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows autostart is available only on Windows.');
    }

    if (!enabled) {
      // Deleting an entry that is already absent is a successful no-op.
      final existing = await Process.run(
        'reg',
        ['query', _runKey, '/v', _valueName],
        runInShell: false,
      );
      if (existing.exitCode != 0) return;

      final removed = await Process.run(
        'reg',
        ['delete', _runKey, '/v', _valueName, '/f'],
        runInShell: false,
      );
      if (removed.exitCode != 0) {
        throw Exception('Не удалось отключить автозапуск: ${removed.stderr}');
      }
      return;
    }

    final executable = Platform.resolvedExecutable;
    final command = '"$executable" --minimized';
    final added = await Process.run(
      'reg',
      [
        'add',
        _runKey,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ],
      runInShell: false,
    );
    if (added.exitCode != 0) {
      throw Exception('Не удалось включить автозапуск: ${added.stderr}');
    }
  }
}
