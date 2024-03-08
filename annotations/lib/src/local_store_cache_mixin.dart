import 'dart:io';

import 'package:annotations/src/base_cache.dart';
import 'package:annotations/src/cache_generator_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:localstore/localstore.dart';
import 'package:path_provider/path_provider.dart';

mixin LocalStoreCacheMixIn implements BaseCache {
  late final CollectionRef _local = Localstore.instance.collection('local');
  late final DocumentRef _db = _local.doc(name);
  final String _notPersistentKey = 'not_persistent';

  String get name;

  @override
  Future<void> deleteAll({bool deletePersistent = false}) {
    if (!deletePersistent) {
      return deleteDoc(_notPersistentKey);
    }
    return _db.delete();
  }

  @override
  Future<int> cacheSize() async {
    int total = 0;
    // Just audio cache
    final cacheDir = await getTemporaryDirectory();
    total += _directorySize(cacheDir.path);
    // Database size minus the ignored values file size
    final docDir = await getApplicationDocumentsDirectory();
    String path = '${docDir.path}${_db.path}.collection/$_notPersistentKey';
    total += _directorySize(path);
    return total;
  }

  static int _directorySize(String dirPath) {
    int totalSize = 0;
    var dir = Directory(dirPath);
    try {
      if (dir.existsSync()) {
        dir
            .listSync(recursive: true, followLinks: false)
            .forEach((FileSystemEntity entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
    } catch (e, s) {
      debugPrint('Failed to get directory size: $dirPath\n$e\n$s');
    }
    return totalSize;
  }

  Future<void> delete(String key, String id, {bool isPersistent = false}) {
    return _db
        .collection(_getDocName(key, isPersistent: isPersistent))
        .doc(id)
        .delete();
  }

  Future<void> deleteDoc(String key, {bool isPersistent = false}) =>
      _db.collection(_getDocName(key, isPersistent: isPersistent)).delete();

  String _getDocName(String key, {required bool isPersistent}) =>
      isPersistent ? key : '$_notPersistentKey/$key';

  Future<T> set<T>(
    String key,
    String id,
    T item, {
    CacheToJson<T>? toJson,
    bool isPersistent = false,
  }) =>
      _db
          .collection(_getDocName(key, isPersistent: isPersistent))
          .doc(id)
          .set(_zip(item, toJson))
          .then((value) => item);

  Future<T?> get<T>(
    String key,
    String id,
    CacheFromJson<T> fromJson, {
    bool isPersistent = false,
  }) async {
    final DocumentRef ref =
        _db.collection(_getDocName(key, isPersistent: isPersistent)).doc(id);
    final value = await ref.get();
    final dynamic data = _unzip(value);
    if (data == null) {
      return null;
    }
    try {
      return fromJson(data);
    } catch (e, s) {
      await ref.delete();
      // ignore: avoid_print
      print('Failed to parse cached data: $e $s');
    }
    return null;
  }

  dynamic _defaultToJson(dynamic item) {
    try {
      return item is Map
          ? item
          : item is Iterable
              ? item.map((e) => e.toJson()).toList()
              : item.toJson();
    } on NoSuchMethodError {
      return item;
    }
  }

  Map<String, dynamic> _zip<T>(T item, CacheToJson<T>? toJson) {
    return {
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'cache': toJson?.call(item) ?? _defaultToJson(item),
    };
  }

  dynamic _unzip(Map<String, dynamic>? data) => data?['cache'];
}
