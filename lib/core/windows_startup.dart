import 'dart:io';

/// Manages the current user's Windows Run entry for Brew.
class WindowsStartup {
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Brew';

  static Future<void> setEnabled(bool enabled, {bool minimized = true}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows startup is available only on Windows.');
    }
    if (enabled) {
      final exe = Platform.resolvedExecutable;
      final command = '"$exe"' + (minimized ? ' --minimized' : '');
      final result = await Process.run('reg.exe', [
        'add', _key, '/v', _valueName, '/t', 'REG_SZ', '/d', command, '/f',
      ], runInShell: false);
      if (result.exitCode != 0) {
        throw ProcessException('reg.exe', ['add', _key],
            '${result.stderr}\n${result.stdout}', result.exitCode);
      }
    } else {
      final result = await Process.run('reg.exe', [
        'delete', _key, '/v', _valueName, '/f',
      ], runInShell: false);
      final output = '${result.stderr}\n${result.stdout}'.toLowerCase();
      if (result.exitCode != 0 && !output.contains('unable to find')) {
        throw ProcessException('reg.exe', ['delete', _key],
            '${result.stderr}\n${result.stdout}', result.exitCode);
      }
    }
  }
}
