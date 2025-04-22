import 'package:analyzer/dart/element/element.dart';
import 'package:cache_annotations/generators.dart';
import 'package:build/build.dart';
import 'package:cache_generators/src/visitor.dart';
import 'package:source_gen/source_gen.dart';

RegExp _iterableTypeRegExp = RegExp(r'^(Iterable|List)<(?<type>[a-zA-Z<>]+)>$');

class LocalStoreCacheGenerator extends GeneratorForAnnotation<LocalStoreCache> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    String name = annotation.read('name').stringValue;

    final Visitor visitor = Visitor(name);
    // Visit class fields and constructor
    element.visitChildren(visitor);

    // Buffer to write each part of generated class
    final buffer = StringBuffer();

    // Generate class
    String generatedChildClass = _generateChildClass(visitor);
    buffer.writeln(generatedChildClass);

    return buffer.toString();
  }

  String _generateChildClass(Visitor visitor) {
    String className = visitor.className;
    final buffer = StringBuffer();
    buffer.writeln(
      '// ignore_for_file: unnecessary_string_interpolations',
    );
    buffer.writeln(
      'class _$className extends $className with LocalStoreCacheMixIn {',
    );
    buffer.writeln('_$className();');

    _generateName(buffer, visitor.name);
    for (CacheEntryMetadata meta in visitor.methods) {
      _generateMethod(buffer, meta);
    }
    buffer.writeln('}');
    buffer.toString();
    return buffer.toString();
  }

  void _generateName(StringBuffer buffer, String name) {
    buffer.writeln('\n@override');
    buffer.writeln('String get name => "$name";');
  }

  void _generateMethod(StringBuffer buffer, CacheEntryMetadata meta) {
    String methodName = meta.name;
    String returnType = meta.type;

    buffer.writeln('\n@override');
    String parameters = _generateMethodParameters(meta.parameters);
    String path = meta.key.formatPath();
    String? name = meta.formatSortBy();

    buffer.writeln(
      'CacheEntry<$returnType> $methodName($parameters) => '
      'SimpleCacheEntry('
      'cache: this, '
      'path: \'$path\', '
      'name: ${name?.isNotEmpty == true ? '\'$name\'' : 'null'}, '
      'isPersistent: ${meta.isPersistent},'
      'maxAge: ${meta.maxAge == null ? 'null' : 'const Duration(microseconds: ${meta.maxAge!.inMicroseconds})'},'
      'fromJson: ${_generateFromJson(returnType, meta.key)},'
      'toJson: ${meta.key.toJson},'
      ');',
    );
  }

  String _generateFromJson(String returnType, KeyMetadata key) {
    if (key.fromJson != null) {
      return key.fromJson!;
    }
    String? type = _iterableTypeRegExp
        .firstMatch(returnType)
        ?.namedGroup('type')
        ?.replaceAll('?', '');
    print('-> $type <- $returnType');
    if (type != null) {
      if (_isPrimitive(type)) {
        return '(json) => (json as List).map((e) => e as $type).toList()';
      }
      return '(json) => (json as List).map((e) => $type.fromJson(e as Map<String, dynamic>)).toList()';
    }
    String safeReturnType = returnType.replaceAll('?', '');
    if (_isPrimitive(safeReturnType)) {
      return '(json) => json as $returnType';
    }
    return '$safeReturnType.fromJson';
  }

  bool _isPrimitive(String type) {
    return type == 'String' ||
        type == 'int' ||
        type == 'double' ||
        type == 'bool' ||
        type == 'num';
  }

  String _generateMethodParameters(final Map<String, String> parameters) {
    if (parameters.isNotEmpty) {
      return parameters.entries.map((e) => '${e.value} ${e.key}').join(', ');
    }
    return '';
  }
}
