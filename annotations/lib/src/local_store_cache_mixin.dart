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
      _db.collection(_notPersistentKey).delete();
    }
    return _local.delete();
  }

  @override
  Future<int> cacheSize() async {
    final docDir = await getApplicationDocumentsDirectory();
    String path = '${docDir.path}${_db.path}.collection/$_notPersistentKey';
    return _directorySize(path);
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
    Duration? maxAge,
    bool isPersistent = false,
  }) =>
      _db
          .collection(_getDocName(key, isPersistent: isPersistent))
          .doc(id)
          .set(_zip(item, maxAge, toJson))
          .then((value) => item);

  Future<T?> get<T>(
    String key,
    String id,
    CacheFromJson<T> fromJson, {
    Duration? maxAge,
    bool isPersistent = false,
  }) async {
    final DocumentRef ref =
        _db.collection(_getDocName(key, isPersistent: isPersistent)).doc(id);
    final value = await ref.get();
    final dynamic data = _unzip('$key/$id', value, maxAge);
    if (data == null) {
      // Delete in cache if expired
      await ref.delete();
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

  Map<String, dynamic> _zip<T>(
    T item,
    Duration? maxAge,
    CacheToJson<T>? toJson,
  ) {
    return {
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'maxAge': maxAge?.inMicroseconds,
      'cache': toJson?.call(item) ?? _defaultToJson(item),
    };
  }

  /// maxAge (method parameter) is the duration provided by the method annotation MaxAge
  /// data?['maxAge'] is the max age duration stored in the cache and
  /// provided by {@CacheEntry#set}
  dynamic _unzip(String tag, Map<String, dynamic>? data, Duration? maxAge) {
    DateTime? createdAt = data?['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data?['createdAt'])
        : null;
    Duration? maxAgeToUse = data?['maxAge'] != null
        ? Duration(microseconds: data!['maxAge'])
        : maxAge;
    if (createdAt != null && maxAgeToUse != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff > maxAgeToUse) {
        debugPrint('Cache expired for "$tag": $diff > $maxAgeToUse');
        return null;
      }
    }
    return data?['cache'];
  }
}
