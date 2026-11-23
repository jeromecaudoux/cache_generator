import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cache_annotations/src/serialization_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'utils_impl.dart';

/// Files bigger than this are deserialized in a background isolate.
///
/// Since Flutter 3.29 the Dart UI code runs on the Android main thread, so a
/// long decode on the UI isolate can trigger an ANR.
const int isolateDeserializeThreshold = 100 * 1024;

/// File system implementation of the store.
///
/// All file accesses are asynchronous: synchronous I/O blocks the UI thread
/// (and therefore the Android main thread) and leads to ANRs.
///
/// Operations on the same file are serialized (see [_synchronized]) so that
/// reads, writes and deletes are applied in the order they were requested.
class Utils implements UtilsImpl {
  Utils._();

  static final Utils _utils = Utils._();
  static final lastPathComponentRegEx = RegExp(r'[^/\\]+[/\\]?$');

  static Utils get instance => _utils;
  String? _customSavePath;
  bool useSupportDir = false;
  final _storageCache = <String, StreamController<Map<String, dynamic>>>{};
  final _fileCache = <String, File>{};
  final _pathLocks = <String, Future<void>>{};

  @override
  void setCustomSavePath(String path) {
    path = _cleanPath(path);
    _customSavePath = path;
  }

  @override
  void setUseSupportDirectory(bool useSupportDir) {
    this.useSupportDir = useSupportDir;
  }

  Future<String> getDatabasePath() async {
    Directory directory;

    if (Platform.isIOS) {
      if (useSupportDir) {
        directory = await getApplicationSupportDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isAndroid) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      directory = await getApplicationCacheDirectory();
    } else {
      // Add other platform-specific directory as needed
      // throw UnsupportedError('This platform is not supported for databases.');
      directory = Directory.current;
    }
    return directory.path;
  }

  @override
  Future<Map<String, dynamic>?> get(
    String path,
    SerializationAdapter adapter, [
    bool? isCollection = false,
    List<List>? conditions,
  ]) {
    path = _cleanPath(path);
    if (isCollection == true) {
      return _getCollection(path, adapter);
    }
    return _getDocument(path, adapter);
  }

  @override
  Future<dynamic>? set(
    Map<String, dynamic> data,
    String path,
    SerializationAdapter adapter,
  ) {
    return _writeFile(data, path, adapter);
  }

  @override
  Future delete(String path) {
    path = _cleanPath(path);
    if (path.endsWith(_separator)) {
      return _deleteDirectory(path);
    }
    return _deleteFile(path);
  }

  @override
  Stream<Map<String, dynamic>> stream(
    String path,
    SerializationAdapter adapter, [
    List<List>? conditions,
  ]) {
    // ignore: close_sinks
    var storage = _storageCache[path];
    if (storage == null) {
      storage = _storageCache.putIfAbsent(
        path,
        () => _newStream(path, adapter),
      );
    } else {
      unawaited(_initStream(storage, path, adapter));
    }
    return storage.stream;
  }

  /// Reads a single document.
  ///
  /// Only the requested file is read: sibling documents are never loaded.
  Future<Map<String, dynamic>?> _getDocument(
    String path,
    SerializationAdapter adapter,
  ) async {
    final data = await _readDocument(path, adapter);
    if (data is! Map<String, dynamic>) {
      return null;
    }
    _notifyStream(path, data);
    return data;
  }

  /// Reads all the documents (direct children) of a collection.
  Future<Map<String, dynamic>?> _getCollection(
    String path,
    SerializationAdapter adapter,
  ) async {
    final fullPath = _customSavePath ?? await getDatabasePath();
    final dir = Directory(_cleanPath(fullPath + path));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return null;
    }
    return _getAll(await _listFiles(dir), adapter);
  }

  Future<Map<String, dynamic>?> _getAll(
    List<File> entries,
    SerializationAdapter adapter,
  ) async {
    final items = <String, dynamic>{};
    final fullPath = _customSavePath ?? await getDatabasePath();
    final dirPath = Directory(fullPath).absolute.path;
    for (final File entry in entries) {
      final path = entry.path.replaceAll(dirPath, '');
      final data = await _readDocument(path, adapter);
      if (data is Map<String, dynamic>) {
        items[path] = data;
      }
    }
    if (items.isEmpty) return null;
    return items;
  }

  /// Creates a stream for the collection at [path].
  ///
  /// Only called when someone explicitly listens to a collection through
  /// [stream], never as a side effect of [get] or [set].
  StreamController<Map<String, dynamic>> _newStream(
    String path,
    SerializationAdapter adapter,
  ) {
    path = _cleanPath(path);
    final storage = StreamController<Map<String, dynamic>>.broadcast();
    unawaited(_initStream(storage, path, adapter));
    return storage;
  }

  /// Emits all the documents of the collection at [path] in [storage].
  Future<void> _initStream(
    StreamController<Map<String, dynamic>> storage,
    String path,
    SerializationAdapter adapter,
  ) async {
    path = _cleanPath(path);
    final fullPath = _customSavePath ?? await getDatabasePath();
    final dir = Directory(fullPath + path);
    try {
      for (final File entry in await _listFiles(dir)) {
        final filePath = entry.absolute.path.replaceAll(dir.absolute.path, '');
        final data = await _readDocument('$path$filePath', adapter);
        if (data is Map<String, dynamic>) {
          storage.add(data);
        }
      }
    } catch (e) {
      // The collection does not exist yet: nothing to emit.
    }
  }

  /// Pushes [data] to the stream of its collection, only if someone
  /// already created this stream with [stream].
  void _notifyStream(String path, Map<String, dynamic> data) {
    final key = path.replaceAll(lastPathComponentRegEx, '');
    _storageCache[key]?.add(data);
  }

  Future<List<File>> _listFiles(Directory dir) {
    return dir
        .list(recursive: false)
        .where((FileSystemEntity e) => e is File)
        .cast<File>()
        .toList();
  }

  String _cleanPath(String path) => path
      .replaceAll('/', _separator)
      .replaceAll('$_separator$_separator', _separator);

  /// Reads and deserializes the document at [path].
  ///
  /// Returns `null` if the file does not exist, the thrown error if the
  /// content can't be deserialized, the deserialized data otherwise.
  Future<dynamic> _readDocument(String path, SerializationAdapter adapter) {
    return _synchronized(_cleanPath(path), () async {
      final file = await _getFile(path);
      if (file == null) {
        return null;
      }
      return _readFile(file, adapter);
    });
  }

  Future<dynamic> _readFile(File file, SerializationAdapter adapter) async {
    final Uint8List buffer;
    try {
      buffer = await file.readAsBytes();
    } on FileSystemException {
      // The file has been removed by someone else in the meantime.
      return null;
    }
    try {
      return await _deserialize(buffer, adapter);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading file: $e');
      }
      return e;
    }
  }

  Future<File?> _getFile(String path, [bool create = false]) async {
    path = _cleanPath(path);
    final cachedFile = _fileCache[path];
    if (cachedFile != null) return cachedFile;

    final file = File(await _fullFilePath(path));
    if (!await file.exists()) {
      if (!create) {
        return null;
      }
      await file.create(recursive: true);
    }
    _fileCache[path] = file;
    return file;
  }

  Future<String> _fullFilePath(String path) async {
    final fullPath = _customSavePath ?? await getDatabasePath();
    return fullPath.endsWith(_separator) || path.startsWith(_separator)
        ? '$fullPath$path'
        : '$fullPath$_separator$path';
  }

  String get _separator => kIsWeb ? '/' : Platform.pathSeparator;

  Future<void> _writeFile(
    Map<String, dynamic> data,
    String path,
    SerializationAdapter adapter,
  ) async {
    path = _cleanPath(path);
    // Serialize now: the caller may mutate [data] after this call.
    final buffer = adapter.serialize(data);
    // No await before this call: the write is queued in the call order.
    await _synchronized(path, () async {
      final file = await _getFile(path, true);
      await _writeBytes(file!, buffer);
    });
    _notifyStream(path, data);
  }

  Future<void> _writeBytes(File file, Uint8List buffer) async {
    final randomAccessFile = await file.open(mode: FileMode.append);
    try {
      await randomAccessFile.lock();
      await randomAccessFile.setPosition(0);
      await randomAccessFile.writeFrom(buffer);
      await randomAccessFile.truncate(buffer.length);
    } finally {
      // Closing the file also releases the lock.
      await randomAccessFile.close();
    }
  }

  Future<void> _deleteFile(String path) {
    return _synchronized(path, () async {
      final file = File(await _fullFilePath(path));
      if (await file.exists()) {
        await file.delete();
      }
      _fileCache.remove(path);
    });
  }

  Future<void> _deleteDirectory(String path) async {
    // Let the pending operations of this directory complete first, otherwise
    // a pending write could re-create a file after the deletion.
    await Future.wait(
      _pathLocks.entries
          .where((entry) => entry.key.startsWith(path))
          .map((entry) => entry.value),
    );
    final fullPath = _customSavePath ?? await getDatabasePath();
    final dir = Directory('$fullPath$path');
    _fileCache.removeWhere((key, value) => key.startsWith(path));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Runs [action] once all the previous actions on [key] are completed.
  ///
  /// Guarantees that the operations on a given file are applied in the order
  /// they were requested, even though the I/O is asynchronous.
  Future<T> _synchronized<T>(String key, Future<T> Function() action) {
    final previous = _pathLocks[key];
    final completer = Completer<void>();
    _pathLocks[key] = completer.future;

    final Future<T> result =
        previous == null ? action() : previous.then((_) => action());
    return result.whenComplete(() {
      completer.complete();
      if (identical(_pathLocks[key], completer.future)) {
        _pathLocks.remove(key);
      }
    });
  }
}

/// Deserializes [buffer], in a background isolate when it is big.
///
/// Top level function on purpose: the closure sent to the isolate must not
/// capture `this` (the [Utils] holds non sendable stream controllers).
Future<Map<String, dynamic>> _deserialize(
  Uint8List buffer,
  SerializationAdapter adapter,
) async {
  if (buffer.length < isolateDeserializeThreshold) {
    return adapter.deserialize(buffer);
  }
  try {
    return await Isolate.run(() => adapter.deserialize(buffer));
  } catch (_) {
    // The adapter may not be sendable to another isolate: decode here.
    return adapter.deserialize(buffer);
  }
}
