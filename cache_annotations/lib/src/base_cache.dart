import 'dart:io';

import 'package:cache_annotations/annotations.dart';

abstract class BaseCache {
  Future<Directory> get directory;

  Future<void> deleteAll({bool deletePersistent = false});

  Future<int> cacheSize();

  Future<Iterable<T>?> all<T>(
    String path, {
    bool isPersistent = false,
    required CacheFromJson<T> fromJson,
    Duration? maxAge,
  });
}
