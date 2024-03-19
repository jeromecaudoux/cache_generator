import 'package:cache_annotations/src/cache_generator_annotations.dart';
import 'package:cache_annotations/src/local_store_cache_mixin.dart';

class SimpleCacheEntry<T> implements CacheEntry<T> {
  final LocalStoreCacheMixIn cache;
  final String path;
  final String? name;
  final bool isPersistent;
  final Duration? maxAge;
  final CacheFromJson<T> fromJson;
  final CacheToJson<T>? toJson;

  SimpleCacheEntry({
    required this.cache,
    required this.path,
    required this.name,
    required this.isPersistent,
    required this.maxAge,
    required this.fromJson,
    required this.toJson,
  });

  @override
  Future<T> set(T value, {Duration? maxAge}) async {
    return cache.set(
      path,
      name,
      value,
      isPersistent: isPersistent,
      maxAge: maxAge,
      toJson: toJson,
    );
  }

  @override
  Future<T?> get() async {
    return cache.get(
      path,
      name,
      fromJson,
      maxAge: maxAge,
      isPersistent: isPersistent,
    );
  }

  @override
  Future<void> delete() => cache.delete(path, name, isPersistent: isPersistent);
}

abstract class CacheEntry<T> {
  Future<T> set(T value, {Duration? maxAge});

  Future<T?> get();

  Future<void> delete();
}
