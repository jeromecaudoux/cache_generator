import 'package:annotations/src/local_store_cache_mixin.dart';
import 'package:annotations/src/cache_generator_annotations.dart';

class SimpleCacheEntry<T> implements CacheEntry<T> {
  final LocalStoreCacheMixIn cache;
  final String key;
  final String? id;
  final bool isPersistent;
  final CacheFromJson<T> fromJson;
  final CacheToJson<T>? toJson;

  SimpleCacheEntry({
    required this.cache,
    required this.key,
    required this.id,
    required this.isPersistent,
    required this.fromJson,
    required this.toJson,
  });

  @override
  Future<T> set(T value) async {
    return cache.set(
      key,
      _id,
      value,
      isPersistent: isPersistent,
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
      isPersistent: isPersistent,
    );
  }

  @override
  Future<void> delete() => cache.delete(key, _id, isPersistent: isPersistent);
}

abstract class CacheEntry<T> {
  Future<T> set(T value);

  Future<T?> get();

  Future<void> delete();
}