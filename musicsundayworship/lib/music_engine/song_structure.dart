import 'dart:convert';

/// Standard section types recognized in song structure.
enum SectionType {
  intro('Intro'),
  verso('Verso'),
  precoro('Pre-coro'),
  coro('Coro'),
  puente('Puente'),
  interludio('Interludio'),
  finalSection('Final'),
  otro('Otro');

  const SectionType(this.displayName);
  final String displayName;

  /// Parses a section type from a human-readable or raw string.
  static SectionType fromString(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.contains('intro')) return SectionType.intro;
    if (clean.contains('pre')) return SectionType.precoro;
    if (clean.contains('coro') ||
        clean.contains('estribillo') ||
        clean.contains('chorus')) {
      return SectionType.coro;
    }
    if (clean.contains('verso') ||
        clean.contains('estrofa') ||
        clean.contains('verse') ||
        clean.contains('parte')) {
      return SectionType.verso;
    }
    if (clean.contains('puente') || clean.contains('bridge')) {
      return SectionType.puente;
    }
    if (clean.contains('inter') ||
        clean.contains('solo') ||
        clean.contains('instrumental')) {
      return SectionType.interludio;
    }
    if (clean.contains('fin') ||
        clean.contains('outro') ||
        clean.contains('coda')) {
      return SectionType.finalSection;
    }
    return SectionType.otro;
  }
}

/// A section entry within an ordered song structure, with repetition counter.
class StructureItem {
  const StructureItem({
    required this.id,
    required this.type,
    required this.name,
    this.repeatCount = 1,
    this.customNote,
  }) : assert(repeatCount >= 1, 'repeatCount must be at least 1');

  final String id;
  final SectionType type;
  final String name;
  final int repeatCount;
  final String? customNote;

  /// Returns a human-readable label including the repetition count (e.g. "Coro x3").
  String get labelWithRepeats => repeatCount > 1 ? '$name x$repeatCount' : name;

  StructureItem copyWith({
    String? id,
    SectionType? type,
    String? name,
    int? repeatCount,
    String? customNote,
  }) {
    return StructureItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      repeatCount: repeatCount ?? this.repeatCount,
      customNote: customNote ?? this.customNote,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'repeatCount': repeatCount,
    if (customNote != null) 'customNote': customNote,
  };

  factory StructureItem.fromJson(Map<String, dynamic> json) => StructureItem(
    id: json['id'] as String? ?? '',
    type: SectionType.fromString(json['type'] as String? ?? 'otro'),
    name: json['name'] as String? ?? '',
    repeatCount: (json['repeatCount'] as int? ?? 1).clamp(1, 99),
    customNote: json['customNote'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StructureItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          name == other.name &&
          repeatCount == other.repeatCount &&
          customNote == other.customNote;

  @override
  int get hashCode => Object.hash(id, type, name, repeatCount, customNote);

  @override
  String toString() => labelWithRepeats;
}

/// An ordered structure (arrangement) of sections for a song.
class SongStructure {
  const SongStructure({
    this.id,
    this.songId,
    required this.name,
    this.items = const [],
    this.isDefault = false,
  });

  final int? id;
  final int? songId;
  final String name;
  final List<StructureItem> items;
  final bool isDefault;

  /// Expands repetitions into individual linear section items.
  /// E.g. Coro x3 expands into 3 individual Coro items.
  List<StructureItem> expand() {
    final expanded = <StructureItem>[];
    for (final item in items) {
      for (var i = 0; i < item.repeatCount; i++) {
        expanded.add(
          item.copyWith(
            id: '${item.id}_rep_${i + 1}',
            repeatCount: 1,
          ),
        );
      }
    }
    return expanded;
  }

  /// Duplicates this structure into an independent, deep copy with an optional new name.
  /// Modifying items in the duplicated copy has zero effect on the original.
  SongStructure duplicate({String? newName, int? newSongId}) {
    return SongStructure(
      id: null,
      songId: newSongId ?? songId,
      name: newName ?? '$name (Copia)',
      isDefault: false,
      items: items
          .map(
            (item) => item.copyWith(
              id: '${item.id}_copy_${DateTime.now().microsecondsSinceEpoch}',
            ),
          )
          .toList(),
    );
  }

  SongStructure copyWith({
    int? id,
    int? songId,
    String? name,
    List<StructureItem>? items,
    bool? isDefault,
  }) {
    return SongStructure(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      name: name ?? this.name,
      items: items ?? this.items,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (songId != null) 'songId': songId,
    'name': name,
    'isDefault': isDefault,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory SongStructure.fromJson(Map<String, dynamic> json) => SongStructure(
    id: json['id'] as int?,
    songId: json['songId'] as int?,
    name: json['name'] as String? ?? 'Estructura',
    isDefault: json['isDefault'] as bool? ?? false,
    items: (json['items'] as List<dynamic>? ?? [])
        .map((item) => StructureItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  String toJsonString() => jsonEncode(toJson());

  factory SongStructure.fromJsonString(String source) =>
      SongStructure.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

