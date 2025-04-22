class LocalStoreCache {
  final String name;

  const LocalStoreCache(this.name);
}

@Deprecated('Use @Cached instead')
class CacheKey<T> {
  final String? path;
  final CacheFromJson<T>? fromJson;
  final CacheToJson<T>? toJson;

  const CacheKey({this.path, this.fromJson, this.toJson});
}

class Cached<T> {
  final String? path;
  final CacheFromJson<T>? fromJson;
  final CacheToJson<T>? toJson;

  const Cached({this.path, this.fromJson, this.toJson});
}

class Path<T, R> {
  final String name;
  final PathConvertor<T, R>? convert;

  const Path(this.name, {this.convert});
}

class MaxAge {
  final Duration maxAge;

  const MaxAge(this.maxAge);
}

@Deprecated('Use path\'s field on @Cached annotation instead')
class SortBy<T, R> {
  final PathConvertor<T, R>? convert;

  const SortBy({this.convert});
}

class Persistent {
  const Persistent();
}

@Deprecated('Use path\'s field on @Cached annotation instead')
const sortBy = SortBy();
const persistent = Persistent();

typedef PathConvertor<T, R> = R Function(T value);
typedef CacheFromJson<T> = T? Function(dynamic json);
typedef CacheToJson<T> = dynamic Function(T value);
