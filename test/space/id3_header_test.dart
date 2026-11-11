import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/space/id3_header.dart';

// The headers of the two tags at the start of a real chunk from X
final _timestampHeader = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3f]);
final _metadataHeader = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x01, 0x19]);

void main() {
  group('Id3Header.read()', () {
    test('Should read the size of the tags that X sends', () {
      expect(Id3Header.read(_timestampHeader)?.tagLength, 10 + 63, reason: 'The header, then 63 bytes');
      expect(Id3Header.read(_metadataHeader)?.tagLength, 10 + 153, reason: '01 19 in base 128 is 1 × 128 + 25');
    });

    test('Should count the footer when the flags say there is one', () {
      final withFooter = Uint8List.fromList([..._timestampHeader.take(5), 0x10, ..._timestampHeader.skip(6)]);

      expect(Id3Header.read(withFooter)?.tagLength, 10 + 63 + 10, reason: 'The footer is as long as the header');
    });

    test('Should find no header in audio', () {
      final adtsFrame = Uint8List.fromList([0xff, 0xf1, 0x4c, 0x80, 0x01, 0x3f, 0xfc, 0x21, 0x00, 0x49]);

      expect(Id3Header.read(adtsFrame), isNull, reason: 'Audio does not start with "ID3"');
    });

    test('Should find no header in fewer than 10 bytes', () {
      expect(Id3Header.read(Uint8List.fromList('ID3'.codeUnits)), isNull, reason: 'The size could not be read');
    });
  });
}
