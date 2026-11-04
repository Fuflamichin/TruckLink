import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// Low-level Windows shared memory reader for SCS telemetry.
///
/// Requires an ETS2/ATS telemetry plugin that publishes
/// the memory mapping named Local\SCSTelemetry.
///
/// This class only reads bytes. Parsing telemetry fields
/// will be implemented in a separate module.
class ScsSharedMemory {
  ScsSharedMemory() : _kernel32 = _loadKernel32();

  static const String mappingName = r'Local\SCSTelemetry';

  static const int _fileMapRead = 0x0004;

  final DynamicLibrary _kernel32;

  static DynamicLibrary _loadKernel32() {
    if (!Platform.isWindows) {
      throw UnsupportedError('SCS shared memory is only supported on Windows.');
    }

    return DynamicLibrary.open('kernel32.dll');
  }

  late final _openFileMapping = _kernel32
      .lookupFunction<_OpenFileMappingNative, _OpenFileMappingDart>(
        'OpenFileMappingW',
      );

  late final _mapViewOfFile = _kernel32
      .lookupFunction<_MapViewOfFileNative, _MapViewOfFileDart>(
        'MapViewOfFile',
      );

  late final _unmapViewOfFile = _kernel32
      .lookupFunction<_UnmapViewOfFileNative, _UnmapViewOfFileDart>(
        'UnmapViewOfFile',
      );

  late final _closeHandle = _kernel32
      .lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');

  late final _localAlloc = _kernel32
      .lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc');

  late final _localFree = _kernel32
      .lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');

  late final _getLastError = _kernel32
      .lookupFunction<_GetLastErrorNative, _GetLastErrorDart>('GetLastError');

  /// Checks whether the telemetry memory mapping exists.
  ///
  /// This does not guarantee that the game is actively
  /// updating telemetry.
  bool get isAvailable {
    final handle = _openMapping();

    if (handle == null) {
      return false;
    }

    _closeHandle(handle);
    return true;
  }

  /// Reads an exact number of bytes from the mapping.
  ///
  /// Returns null when the mapping does not exist.
  ///
  /// Throws StateError when a Windows API operation fails.
  Uint8List? readBytes(int byteCount) {
    if (byteCount <= 0 || byteCount > 1024 * 1024) {
      throw RangeError.range(byteCount, 1, 1024 * 1024, 'byteCount');
    }

    final handle = _openMapping();

    if (handle == null) {
      return null;
    }

    try {
      final view = _mapViewOfFile(handle, _fileMapRead, 0, 0, byteCount);

      if (view.address == 0) {
        final error = _getLastError();

        throw StateError('MapViewOfFile failed. Windows error: $error');
      }

      try {
        // Copy bytes before releasing the mapped view.
        return Uint8List.fromList(view.cast<Uint8>().asTypedList(byteCount));
      } finally {
        _unmapViewOfFile(view);
      }
    } finally {
      _closeHandle(handle);
    }
  }

  Pointer<Void>? _openMapping() {
    final codeUnits = mappingName.codeUnits;

    final buffer = _localAlloc(0, (codeUnits.length + 1) * sizeOf<Uint16>());

    if (buffer.address == 0) {
      throw StateError('LocalAlloc failed.');
    }

    try {
      final chars = buffer.cast<Uint16>().asTypedList(codeUnits.length + 1);

      for (var i = 0; i < codeUnits.length; i++) {
        chars[i] = codeUnits[i];
      }

      chars[codeUnits.length] = 0;

      final handle = _openFileMapping(_fileMapRead, 0, buffer.cast<Uint16>());

      if (handle.address == 0) {
        final error = _getLastError();

        // ERROR_FILE_NOT_FOUND / ERROR_PATH_NOT_FOUND
        if (error == 2 || error == 3) {
          return null;
        }

        throw StateError('OpenFileMappingW failed. Windows error: $error');
      }

      return handle;
    } finally {
      _localFree(buffer);
    }
  }
}

// Windows API function signatures.

typedef _OpenFileMappingNative =
    Pointer<Void> Function(Uint32, Int32, Pointer<Uint16>);

typedef _OpenFileMappingDart =
    Pointer<Void> Function(int, int, Pointer<Uint16>);

typedef _MapViewOfFileNative =
    Pointer<Void> Function(Pointer<Void>, Uint32, Uint32, Uint32, IntPtr);

typedef _MapViewOfFileDart =
    Pointer<Void> Function(Pointer<Void>, int, int, int, int);

typedef _UnmapViewOfFileNative = Int32 Function(Pointer<Void>);

typedef _UnmapViewOfFileDart = int Function(Pointer<Void>);

typedef _CloseHandleNative = Int32 Function(Pointer<Void>);

typedef _CloseHandleDart = int Function(Pointer<Void>);

typedef _LocalAllocNative = Pointer<Void> Function(Uint32, IntPtr);

typedef _LocalAllocDart = Pointer<Void> Function(int, int);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void>);

typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void>);

typedef _GetLastErrorNative = Uint32 Function();

typedef _GetLastErrorDart = int Function();
