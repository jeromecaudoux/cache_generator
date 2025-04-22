library cache_generators;

import 'package:build/build.dart';
import 'package:cache_generators/src/local_store_cache_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder generateJsonMethods(BuilderOptions options) {
  return SharedPartBuilder(
    [LocalStoreCacheGenerator()],
    'cache_generators',
  );
}
