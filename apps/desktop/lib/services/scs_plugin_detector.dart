import 'dart:io';

// ============================================
// ONE DETECTED GAME INSTALLATION
// ============================================

class ScsGameInstallation {
  const ScsGameInstallation({
    required this.name,
    required this.directory,
    required this.pluginInstalled,
  });

  final String name;
  final String directory;
  final bool pluginInstalled;
}

// ============================================
// PLUGIN SCAN RESULT
// ============================================

class ScsPluginScanResult {
  const ScsPluginScanResult(this.games);

  final List<ScsGameInstallation> games;

  bool get hasGames => games.isNotEmpty;

  bool get hasPlugin => games.any((game) => game.pluginInstalled);

  bool get hasMissingPlugin => games.any((game) => !game.pluginInstalled);

  bool get allInstalled => hasGames && !hasMissingPlugin;
}

// ============================================
// SCS PLUGIN DETECTOR
// ============================================

class ScsPluginDetector {
  const ScsPluginDetector();

  static const String pluginName = 'scs-telemetry.dll';

  static const String downloadUrl =
      'https://github.com/truckermudgeon/'
      'scs-sdk-plugin/releases';

  // ==========================================
  // PATH HELPERS
  // ==========================================

  String _join(String left, String right) {
    if (left.endsWith('\\')) {
      return '$left$right';
    }

    return '$left\\$right';
  }

  String _normalize(String value) {
    return value.trim().replaceAll('/', '\\').replaceAll(r'\\', '\\');
  }

  // ==========================================
  // STEAM ROOTS
  // ==========================================

  Future<Set<String>> _steamRoots() async {
    final result = <String>{};

    void add(String? value) {
      if (value == null || value.trim().isEmpty) {
        return;
      }

      result.add(_normalize(value));
    }

    final env = Platform.environment;

    final programFilesX86 = env['ProgramFiles(x86)'];

    final programFiles = env['ProgramFiles'];

    if (programFilesX86 != null) {
      add(_join(programFilesX86, 'Steam'));
    }

    if (programFiles != null) {
      add(_join(programFiles, 'Steam'));
    }

    final systemDrive = env['SystemDrive'] ?? 'C:';

    add('$systemDrive\\Steam');
    add('$systemDrive\\SteamLibrary');

    // Steam may have been installed to a
    // non-default path.
    try {
      final result = await Process.run('reg.exe', [
        'query',
        r'HKCU\Software\Valve\Steam',
        '/v',
        'SteamPath',
      ]);

      if (result.exitCode == 0) {
        final text = result.stdout.toString();

        final match = RegExp(
          r'SteamPath\s+REG_SZ\s+(.+)',
          caseSensitive: false,
        ).firstMatch(text);

        if (match != null) {
          add(match.group(1));
        }
      }
    } catch (_) {
      // Registry lookup is optional.
    }

    return result;
  }

  // ==========================================
  // STEAM LIBRARIES
  // ==========================================

  Future<Set<String>> _steamLibraries() async {
    final libraries = <String>{};

    final roots = await _steamRoots();

    for (final root in roots) {
      final steamApps = _join(root, 'steamapps');

      if (!await Directory(steamApps).exists()) {
        continue;
      }

      libraries.add(steamApps);

      final vdfFile = File(_join(steamApps, 'libraryfolders.vdf'));

      if (!await vdfFile.exists()) {
        continue;
      }

      try {
        final source = await vdfFile.readAsString();

        // Steam VDF:
        // "path" "D:\\SteamLibrary"
        final paths = RegExp(
          r'"path"\s*"([^"]+)"',
          caseSensitive: false,
        ).allMatches(source);

        for (final match in paths) {
          final rawPath = match.group(1);

          if (rawPath == null) {
            continue;
          }

          final path = _join(_normalize(rawPath), 'steamapps');

          if (await Directory(path).exists()) {
            libraries.add(path);
          }
        }
      } catch (_) {
        // Continue with other Steam libraries.
      }
    }

    return libraries;
  }

  // ==========================================
  // CHECK A SINGLE GAME
  // ==========================================

  Future<ScsGameInstallation?> _checkGame(
    String steamApps,
    String folderName,
    String shortName,
  ) async {
    final gameDirectory = _join(_join(steamApps, 'common'), folderName);

    if (!await Directory(gameDirectory).exists()) {
      return null;
    }

    final pluginDirectory = _join(
      _join(_join(gameDirectory, 'bin'), 'win_x64'),
      'plugins',
    );

    final pluginFile = File(_join(pluginDirectory, pluginName));

    return ScsGameInstallation(
      name: shortName,
      directory: gameDirectory,
      pluginInstalled: await pluginFile.exists(),
    );
  }

  // ==========================================
  // SCAN INSTALLED GAMES
  // ==========================================

  Future<ScsPluginScanResult> scan() async {
    if (!Platform.isWindows) {
      return const ScsPluginScanResult([]);
    }

    final libraries = await _steamLibraries();

    final games = <String, ScsGameInstallation>{};

    for (final library in libraries) {
      final ets2 = await _checkGame(library, 'Euro Truck Simulator 2', 'ETS2');

      if (ets2 != null) {
        games['ETS2'] = ets2;
      }

      final ats = await _checkGame(library, 'American Truck Simulator', 'ATS');

      if (ats != null) {
        games['ATS'] = ats;
      }
    }

    return ScsPluginScanResult(List.unmodifiable(games.values));
  }
}
