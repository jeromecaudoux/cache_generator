library generators;

import 'package:build/build.dart';
import 'package:generators/src/local_store_cache_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder generateJsonMethods(BuilderOptions options) {
  // Step 1
  return SharedPartBuilder(
    [LocalStoreCacheGenerator()], // Step 2
    'cache_generator', // Step 3
  );
}
