import 'dart:io';
import 'dart:typed_data';

import '../lib/services/scs_shared_memory.dart';

Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('Ошибка: проверка доступна только на Windows.');
    exitCode = 1;
    return;
  }

  final memory = ScsSharedMemory();

  stdout.writeln('================================');
  stdout.writeln('TruckLink - SCS Plugin Diagnostic');
  stdout.writeln('================================');
  stdout.writeln();
  stdout.writeln('Mapping: ${ScsSharedMemory.mappingName}');
  stdout.writeln('Запусти ETS2 и загрузи грузовик.');
  stdout.writeln('Для завершения нажми Ctrl+C.');
  stdout.writeln();

  int? previousTimestamp;
  var mappingDetected = false;

  while (true) {
    try {
      // The plugin's memory mapping is 32 KiB.
      // Only the first 64 bytes are needed for diagnostics.
      final bytes = memory.readBytes(64);

      if (bytes == null) {
        if (mappingDetected) {
          stdout.writeln('[DISCONNECTED] Shared memory больше недоступна.');
        } else {
          stdout.writeln('[WAITING] Ожидание SCS Telemetry Plugin...');
        }

        mappingDetected = false;
        previousTimestamp = null;
      } else {
        if (!mappingDetected) {
          stdout.writeln('[CONNECTED] Shared memory обнаружена!');
          mappingDetected = true;
        }

        final data = ByteData.sublistView(bytes);

        // Layout from scs-telemetry-common.hpp,
        // telemetry map revision 12.
        final sdkActive = bytes[0] != 0;
        final paused = bytes[4] != 0;

        final timestamp = data.getUint64(8, Endian.little);

        final revision = data.getUint32(40, Endian.little);

        final gameMajor = data.getUint32(44, Endian.little);

        final gameMinor = data.getUint32(48, Endian.little);

        final gameId = data.getUint32(52, Endian.little);

        final gameName = switch (gameId) {
          1 => 'ETS2',
          2 => 'ATS',
          _ => 'Unknown ($gameId)',
        };

        final isUpdating =
            previousTimestamp != null && timestamp != previousTimestamp;

        stdout.writeln('--------------------------------');
        stdout.writeln('Game:       $gameName');
        stdout.writeln('Version:    $gameMajor.$gameMinor');
        stdout.writeln('Revision:   $revision');
        stdout.writeln('SDK active: $sdkActive');
        stdout.writeln('Paused:     $paused');
        stdout.writeln('Timestamp:  $timestamp');

        if (isUpdating) {
          stdout.writeln('[OK] Данные обновляются!');
        } else if (previousTimestamp == null) {
          stdout.writeln('[INFO] Ожидание следующего обновления...');
        } else {
          stdout.writeln('[INFO] Timestamp пока не изменился.');
        }

        previousTimestamp = timestamp;
      }
    } catch (error) {
      stderr.writeln('[ERROR] $error');
    }

    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
