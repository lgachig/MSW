import 'note_name.dart';

/// A chord with a root, quality and optional slash bass note.
class Chord {
  const Chord({required this.root, this.quality = '', this.bass});

  final NoteName root;
  final String quality;
  final NoteName? bass;

  /// Reads a chord in American notation, or returns null for invalid text.
  static Chord? parse(String value) {
    final match = RegExp(r'^([A-G](?:#|b)?)([^/]*)(?:/([A-G](?:#|b)?))?$')
        .firstMatch(value);
    if (match == null) return null;

    final root = NoteName.parse(match.group(1)!);
    final quality = match.group(2)!;
    final bassText = match.group(3);
    final bass = bassText == null ? null : NoteName.parse(bassText);
    if (root == null || (bassText != null && bass == null)) return null;
    if (!_isQuality(quality)) return null;
    return Chord(root: root, quality: quality, bass: bass);
  }

  static Chord? fromString(String value) => parse(value);

  static bool _isQuality(String quality) {
    if (quality.isEmpty) return true;
    // Keep the accepted vocabulary explicit so ordinary words are not chords.
    return RegExp(
      r'^(?:m|min|maj|dim|aug|sus2|sus4|add[0-9]+|[0-9]+|'
      r'(?:m|min|maj|dim|aug)?[0-9]+(?:b5|#5|b9|#9|add[0-9]+)*|'
      r'(?:sus2|sus4)(?:add[0-9]+)*)$',
    ).hasMatch(quality);
  }

  @override
  String toString() => '$root$quality${bass == null ? '' : '/$bass'}';

  @override
  bool operator ==(Object other) =>
      other is Chord &&
      other.root == root &&
      other.quality == quality &&
      other.bass == bass;

  @override
  int get hashCode => Object.hash(root, quality, bass);
}
