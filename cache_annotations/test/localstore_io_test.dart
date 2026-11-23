import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cache_annotations/annotations.dart';
import 'package:cache_annotations/src/localstore/localstore.dart';
import 'package:cache_annotations/src/localstore/src/utils/io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the number of deserialized documents (i.e. the number of reads).
class CountingAdapter extends JsonSerializationAdapter {
  int reads = 0;

  @override
  Map<String, dynamic> deserialize<T>(Uint8List raw) {
    reads++;
    return super.deserialize(raw);
  }
}

late Directory root;

void writeRawDocument(String path, Map<String, dynamic> data) {
  File('${root.path}$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(data));
}

void writeSiblings(String collection, int count) {
  for (int i = 0; i < count; i++) {
    writeRawDocument('$collection/doc$i', {'i': i});
  }
}

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  final Utils utils = Utils.instance;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('cache_annotations_test');
    utils.setCustomSavePath(root.path);
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  group('reads', () {
    test('get only reads the requested document', () async {
      writeSiblings('/read-one', 20);
      final adapter = CountingAdapter();

      expect(await utils.get('/read-one/doc5', adapter), {'i': 5});
      expect(adapter.reads, 1);

      expect(await utils.get('/read-one/doc6', adapter), {'i': 6});
      expect(adapter.reads, 2);
    });

    test('get of a missing document returns null', () async {
      expect(await utils.get('/missing/doc', JsonSerializationAdapter()), null);
    });

    test('get of a corrupted document returns null', () async {
      File('${root.path}/corrupted/doc')
        ..createSync(recursive: true)
        ..writeAsStringSync('{not json');
      expect(
        await utils.get('/corrupted/doc', JsonSerializationAdapter()),
        null,
      );
    });

    test('get of a collection returns all its documents', () async {
      writeSiblings('/collection', 5);
      final Map<String, dynamic>? all =
          await utils.get('/collection/', JsonSerializationAdapter(), true);
      expect(all?.length, 5);
      expect(all?['/collection/doc3'], {'i': 3});
    });

    test('big documents are deserialized', () async {
      final data = <String, dynamic>{
        'items': List.generate(20000, (i) => 'item number $i'),
      };
      final adapter = JsonSerializationAdapter();
      expect(
        adapter.serialize(data).length,
        greaterThan(isolateDeserializeThreshold),
      );

      await utils.set(data, '/big/doc', adapter);
      expect(await utils.get('/big/doc', adapter), data);
    });
  });

  group('writes', () {
    test('set does not read sibling documents', () async {
      writeSiblings('/write-one', 20);
      final adapter = CountingAdapter();

      await utils.set({'v': 1}, '/write-one/new', adapter);
      expect(adapter.reads, 0);
    });

    test('set then get returns the written data', () async {
      final adapter = JsonSerializationAdapter();
      await utils.set({'v': 1}, '/set-get/doc', adapter);
      expect(await utils.get('/set-get/doc', adapter), {'v': 1});
    });

    test('overwriting with a smaller document truncates the file', () async {
      final adapter = JsonSerializationAdapter();
      await utils.set({'v': 'a long value'}, '/truncate/doc', adapter);
      await utils.set({'v': 1}, '/truncate/doc', adapter);
      expect(
        File('${root.path}/truncate/doc').readAsStringSync(),
        '{"v":1}',
      );
    });

    test('concurrent writes on the same file are applied in order', () async {
      final adapter = JsonSerializationAdapter();
      final writes = [
        for (int i = 0; i < 50; i++)
          utils.set({'v': i}, '/ordered/doc', adapter),
      ];
      await Future.wait(writes.whereType<Future>());

      expect(await utils.get('/ordered/doc', adapter), {'v': 49});
      expect(
        jsonDecode(File('${root.path}/ordered/doc').readAsStringSync()),
        {'v': 49},
      );
    });
  });

  group('deletes', () {
    test('delete after a pending write removes the file', () async {
      final adapter = JsonSerializationAdapter();
      unawaited(utils.set({'v': 1}, '/pending-delete/doc', adapter));
      await utils.delete('/pending-delete/doc');

      expect(await utils.get('/pending-delete/doc', adapter), null);
      expect(File('${root.path}/pending-delete/doc').existsSync(), false);
    });

    test('delete of a directory waits for the pending writes', () async {
      final adapter = JsonSerializationAdapter();
      for (int i = 0; i < 10; i++) {
        unawaited(utils.set({'i': i}, '/pending-dir/doc$i', adapter));
      }
      await utils.delete('/pending-dir/');

      expect(Directory('${root.path}/pending-dir').existsSync(), false);
    });

    test('collection delete clears the documents kept in memory', () async {
      final adapter = JsonSerializationAdapter();
      final CollectionRef collection =
          Localstore.getInstance(customPath: root.path).collection('memory');
      final DocumentRef doc = collection.doc('doc');

      await doc.set({'v': 1}, adapter);
      expect(await doc.get(adapter), {'v': 1});

      await collection.delete(adapter);
      expect(await doc.get(adapter), null);
      expect(Directory('${root.path}/memory').existsSync(), false);
    });
  });

  group('stream', () {
    test('emits the existing documents then the new ones', () async {
      final adapter = JsonSerializationAdapter();
      await utils.set({'v': 'a'}, '/stream/a', adapter);

      final events = <Map<String, dynamic>>[];
      final subscription = utils.stream('/stream/', adapter).listen(events.add);
      await waitUntil(() => events.isNotEmpty);

      await utils.set({'v': 'b'}, '/stream/b', adapter);
      await waitUntil(() => events.length == 2);
      await subscription.cancel();

      expect(events, [
        {'v': 'a'},
        {'v': 'b'},
      ]);
    });
  });
}
