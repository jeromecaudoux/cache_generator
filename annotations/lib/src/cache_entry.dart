import 'package:annotations/src/cache_generator_annotations.dart';
import 'package:annotations/src/local_store_cache_mixin.dart';

class SimpleCacheEntry<T> implements CacheEntry<T> {
  final LocalStoreCacheMixIn cache;
  final String key;
  final String? id;
  final bool isPersistent;
  final Duration? maxAge;
  final CacheFromJson<T> fromJson;
  final CacheToJson<T>? toJson;

  SimpleCacheEntry({
    required this.cache,
    required this.key,
    required this.id,
    required this.isPersistent,
    required this.maxAge,
    required this.fromJson,
    required this.toJson,
  });

  @override
  Future<T> set(T value, {Duration? maxAge}) async {
    return cache.set(
      key,
      _id,
      value,
      isPersistent: isPersistent,
      maxAge: maxAge,
      toJson: toJson,
    );
  }

  String get _id => id ?? 'values';

  @override
  Future<T?> get() async {
    return cache.get(
      key,
      _id,
      fromJson,
      maxAge: maxAge,
      isPersistent: isPersistent,
    );
  }

  @override
  Future<void> delete() => cache.delete(key, _id, isPersistent: isPersistent);
}

abstract class CacheEntry<T> {
  Future<T> set(T value, {Duration? maxAge});

  Future<T?> get();

  Future<void> delete();
}
