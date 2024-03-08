
abstract class BaseCache {
  Future<void> deleteAll({bool deletePersistent = false});
  Future<int> cacheSize();
}