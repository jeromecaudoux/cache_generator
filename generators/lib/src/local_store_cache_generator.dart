import 'package:analyzer/dart/element/element.dart';
import 'package:annotations/generators.dart';
import 'package:build/build.dart';
import 'package:generators/src/visitor.dart';
import 'package:source_gen/source_gen.dart';

RegExp _iterableTypeRegExp = RegExp(r'^Iterable<(?<type>[a-zA-Z<>]+)>$');

class LocalStoreCacheGenerator extends GeneratorForAnnotation<LocalStoreCache> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    String name = annotation.read('name').stringValue;
    print('Generating cache for $name');

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
        'class _$className with LocalStoreCacheMixIn implements $className {');
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
    String key = meta.key.formatKey();
    String? sortBy = meta.formatSortBy();
    buffer.writeln(
      'CacheEntry<$returnType> $methodName($parameters) => '
      'SimpleCacheEntry('
      'cache: this, '
      'key: \'$key\', '
      'id: ${sortBy == null ? null : "'$sortBy'"}, '
      'isPersistent: ${meta.isPersistent},'
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
    if (type != null) {
      if (_isPrimitive(type)) {
        return '(json) => (json as List).map((e) => e as $type).toList()';
      }
      return '(json) => (json as List).map($type.fromJson).toList()';
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
