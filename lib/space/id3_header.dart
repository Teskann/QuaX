import 'dart:typed_data';

/// The start of an ID3 tag. A tag holds data about the audio, like its title.
///
/// Its 10 bytes are: "ID3", the version (2 bytes), the flags (1 byte) and the size (4 bytes).
class Id3Header {
  static const headerLength = 10;

  static const _footerFlag = 0x10;

  /// The size of the tag, without the header and the footer.
  final int bodyLength;

  final bool hasFooter;

  const Id3Header({required this.bodyLength, required this.hasFooter});

  /// Reads the header at the start of [bytes]. Null if there is none.
  static Id3Header? read(Uint8List bytes) {
    if (bytes.length < headerLength || String.fromCharCodes(bytes.take(3)) != 'ID3') return null;
    final flags = bytes[5];
    final sizeDigits = bytes.sublist(6, 10);
    return Id3Header(bodyLength: _fromBase128(sizeDigits), hasFooter: flags & _footerFlag != 0);
  }

  /// The length of the whole tag. The footer has the same length as the header.
  int get tagLength => headerLength + bodyLength + (hasFooter ? headerLength : 0);
}

// Sizes are in base 128. So no byte looks like the start of audio.
int _fromBase128(List<int> digits) => digits.fold(0, (number, digit) => number * 128 + digit);
