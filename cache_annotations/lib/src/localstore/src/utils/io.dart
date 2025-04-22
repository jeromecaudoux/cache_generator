import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'utils_impl.dart';

class Utils implements UtilsImpl {
  Utils._();

  static final Utils _utils = Utils._();
  static final lastPathComponentRegEx = RegExp(r'[^/\\]+[/\\]?$');

  static Utils get instance => _utils;
  String? _customSavePath;
  bool useSupportDir = false;
  final _storageCache = <String, StreamController<Map<String, dynamic>>>{};
  final _fileCache = <String, File>{};

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
  Future<Map<String, dynamic>?> get(String path,
      [bool? isCollection = false, List<List>? conditions]) async {
    // Fetch the documents for this collection
    path = _cleanPath(path);
    if (isCollection != null && isCollection == true) {
      final fullPath = _customSavePath ?? await getDatabasePath();
      final dir = Directory(_cleanPath(fullPath + path));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      List<FileSystemEntity> entries =
          dir.listSync(recursive: false).whereType<File>().toList();
      if (conditions != null && conditions.first.isNotEmpty) {
        return await _getAll(entries);
        /*
        // With conditions
        entries.forEach((e) async {
          final path = e.path.replaceAll(_docDir!.absolute.path, '');
          final file = await _getFile(path);
          _readFile(file!).then((data) {
            if (data is Map<String, dynamic>) {
              _data[path] = data;
            }
          });
        });
        return _data;
        */
      } else {
        return await _getAll(entries);
      }
    } else {
      // Reads the document referenced by this [DocumentRef].
      final file = await _getFile(path);
      if (file == null) {
        return null;
      }
      final randomAccessFile = file.openSync(mode: FileMode.append);
      final data = await _readFile(randomAccessFile);
      randomAccessFile.closeSync();
      if (data is Map<String, dynamic>) {
        final key = path.replaceAll(lastPathComponentRegEx, '');
        // ignore: close_sinks
        final storage = _storageCache.putIfAbsent(key, () => _newStream(key));
        storage.add(data);
        return data;
      }
    }
    return null;
  }

  @override
  Future<dynamic>? set(Map<String, dynamic> data, String path) {
    return _writeFile(data, path);
  }

  @override
  Future delete(String path) async {
    path = _cleanPath(path);
    if (path.endsWith(_separator)) {
      return _deleteDirectory(path);
    } else {
      return _deleteFile(path);
    }
  }

  @override
  Stream<Map<String, dynamic>> stream(String path, [List<List>? conditions]) {
    // ignore: close_sinks
    var storage = _storageCache[path];
    if (storage == null) {
      storage = _storageCache.putIfAbsent(path, () => _newStream(path));
    } else {
      _initStream(storage, path);
    }
    return storage.stream;
  }

  Future<Map<String, dynamic>?> _getAll(List<FileSystemEntity> entries) async {
    final items = <String, dynamic>{};
    final dbPath = await getDatabasePath();
    final fullPath = _customSavePath ?? dbPath;
    final dir = Directory(fullPath);
    await Future.forEach(entries, (FileSystemEntity e) async {
      final path = e.path.replaceAll(dir.absolute.path, '');
      final file = await _getFile(path);
      if (file == null) {
        return;
      }
      final randomAccessFile = await file.open(mode: FileMode.append);
      final data = await _readFile(randomAccessFile);
      await randomAccessFile.close();

      if (data is Map<String, dynamic>) {
        items[path] = data;
      }
    });

    if (items.isEmpty) return null;
    return items;
  }

  /// Streams all file in the path
  StreamController<Map<String, dynamic>> _newStream(String path) {
    path = _cleanPath(path);
    final storage = StreamController<Map<String, dynamic>>.broadcast();
    _initStream(storage, path);

    return storage;
  }

  Future _initStream(
    StreamController<Map<String, dynamic>> storage,
    String path,
  ) async {
    path = _cleanPath(path);
    final fullPath = _customSavePath ?? await getDatabasePath();
    final dir = Directory(fullPath + path);
    try {
      List<FileSystemEntity> entries =
          dir.listSync(recursive: false).whereType<File>().toList();
      for (FileSystemEntity e in entries) {
        final filePath = e.absolute.path.replaceAll(dir.absolute.path, '');
        final file = await _getFile('$path$filePath');
        if (file == null) {
          continue;
        }
        final randomAccessFile = file.openSync(mode: FileMode.append);
        _readFile(randomAccessFile).then((data) {
          randomAccessFile.closeSync();
          if (data is Map<String, dynamic>) {
            storage.add(data);
          }
        });
      }
    } catch (e) {
      return e;
    }
  }

  String _cleanPath(String path) => path
      .replaceAll('/', _separator)
      .replaceAll('$_separator$_separator', _separator);

  Future<dynamic> _readFile(RandomAccessFile file) async {
    final length = file.lengthSync();
    file.setPositionSync(0);
    final buffer = Uint8List(length);
    file.readIntoSync(buffer);
    try {
      final contentText = utf8.decode(buffer);
      final data = json.decode(contentText) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return e;
    }
  }

  Future<File?> _getFile(String path, [bool create = false]) async {
    path = _cleanPath(path);
    if (_fileCache.containsKey(path)) return _fileCache[path];

    final fullPath = _customSavePath ?? await getDatabasePath();
    final filePath =
        fullPath.endsWith(_separator) || path.startsWith(_separator)
            ? '$fullPath$path'
            : '$fullPath$_separator$path';
    final file = File(filePath);

    if (!file.existsSync()) {
      if (!create) {
        return null;
      }
      file.createSync(recursive: true);
    }
    _fileCache.putIfAbsent(path, () => file);

    return file;
  }

  String get _separator => kIsWeb ? '/' : Platform.pathSeparator;

  Future _writeFile(Map<String, dynamic> data, String path) async {
    path = _cleanPath(path);
    final serialized = json.encode(data);
    final buffer = utf8.encode(serialized);
    final file = await _getFile(path, true);
    final randomAccessFile = file!.openSync(mode: FileMode.append);

    randomAccessFile.lockSync();
    randomAccessFile.setPositionSync(0);
    randomAccessFile.writeFromSync(buffer);
    randomAccessFile.truncateSync(buffer.length);
    randomAccessFile.unlockSync();
    randomAccessFile.closeSync();

    final key = path.replaceAll(lastPathComponentRegEx, '');
    // ignore: close_sinks
    final storage = _storageCache.putIfAbsent(key, () => _newStream(key));
    storage.add(data);
  }

  Future _deleteFile(String path) async {
    path = _cleanPath(path);
    final fullPath = _customSavePath ?? await getDatabasePath();
    final file = File(fullPath.endsWith(_separator)
        ? '$fullPath$path'
        : '$fullPath$_separator$path');

    if (file.existsSync()) {
      file.deleteSync();
      _fileCache.remove(path);
    }
  }

  Future _deleteDirectory(String path) async {
    path = _cleanPath(path);
    final fullPath = _customSavePath ?? await getDatabasePath();
    final dir = Directory('$fullPath$path');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      _fileCache.removeWhere((key, value) => key.startsWith(path));
    }
  }
}
