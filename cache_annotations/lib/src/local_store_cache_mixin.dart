import 'dart:io';

import 'package:cache_annotations/annotations.dart';
import 'package:cache_annotations/src/localstore/localstore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

mixin LocalStoreCacheMixIn implements BaseCache {
  CollectionRef? _local;
  final String _notPersistentKey = 'not_persistent';

  String get name;

  @override
  Future<Directory> get directory async {
    if (kIsWeb) {
      return Directory('/');
    }
    return getApplicationCacheDirectory();
  }

  Future<DocumentRef> get _ensureDb async {
    _local ??= Localstore.getInstance(customPath: (await directory).path)
        .collection('local');
    return _local!.doc(name);
  }

  @override
  Future<void> deleteAll({bool deletePersistent = false}) async {
    DocumentRef db = await _ensureDb;
    if (!deletePersistent) {
      return db.collection(_notPersistentKey).delete();
    }
    return _local!.delete();
  }

  String get _separator => kIsWeb ? '/' : Platform.pathSeparator;

  @override
  Future<int> cacheSize() async {
    final Directory docDir = await directory;
    String path =
        '${docDir.path}${(await _ensureDb).path}.collection$_separator$_notPersistentKey';
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

  Future<void> delete(
    String path,
    String? name, {
    bool isPersistent = false,
  }) async {
    return (await _documentRef(path, name, isPersistent: isPersistent))
        .delete();
  }

  // Future<void> deleteDoc(String path, {bool isPersistent = false}) =>
  //     _db.collection(_getCollection(path, isPersistent: isPersistent)).delete();

  @override
  Future<Iterable<T>?> all<T>(
    String path, {
    bool isPersistent = false,
    required CacheFromJson<T> fromJson,
    Duration? maxAge,
  }) async {
    final CollectionRef ref =
        await _collectionRef(path, isPersistent: isPersistent);
    try {
      return ref.get().then(
        (items) {
          return items?.entries.map((pair) {
            final tag = pair.key.split('/').last;
            final dynamic data = _unzip(tag, pair.value, maxAge);
            if (data == null) {
              return null;
            }
            return fromJson(data);
          }).whereType();
        },
      );
    } catch (e, s) {
      await ref.delete();
      debugPrint('Failed to parse cached data: $e $s');
    }
    return null;
  }

  Future<void> deleteCollection(
    String path, {
    bool isPersistent = false,
  }) async {
    final CollectionRef ref =
        await _collectionRef(path, isPersistent: isPersistent);
    return ref.delete();
  }

  Future<CollectionRef> _collectionRef(
    String path, {
    required bool isPersistent,
  }) async {
    String prefix = isPersistent ? '' : '$_notPersistentKey$_separator';
    DocumentRef db = await _ensureDb;
    return db.collection('$prefix${_separator}values$_separator$path');
  }

  Future<DocumentRef> _documentRef(
    String path,
    String? name, {
    required bool isPersistent,
  }) async {
    String prefix = isPersistent ? '' : '$_notPersistentKey$_separator';
    DocumentRef db = await _ensureDb;
    if (name?.isNotEmpty == true) {
      return db.collection('$prefix$path').doc(name!);
    }
    return db.collection('${prefix}values').doc(path);
  }

  Future<T> set<T>(
    String path,
    String? name,
    T item, {
    CacheToJson<T>? toJson,
    Duration? maxAge,
    bool isPersistent = false,
  }) async {
    return (await _documentRef(path, name, isPersistent: isPersistent))
        .set(_zip(item, maxAge, toJson))
        .then((value) => item);
  }

  Future<T?> get<T>(
    String path,
    String? name,
    CacheFromJson<T> fromJson, {
    Duration? maxAge,
    bool isPersistent = false,
  }) async {
    final DocumentRef ref =
        await _documentRef(path, name, isPersistent: isPersistent);
    final value = await ref.get();
    final dynamic data = _unzip('$path/$name', value, maxAge);
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

  String safePath(dynamic value) {
    String name = value.toString();
    if (name.isEmpty) {
      return '_';
    }
    return name.replaceAll(_separator, '_');
  }
}
