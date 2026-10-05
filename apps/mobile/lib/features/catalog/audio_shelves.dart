import '../../core/track.dart';

enum AudioShelf {
  doua('doua', 'Doua'),
  zyaraate('zyaraate', 'Zyaraate'),
  aamal('aamal', 'Aamal'),
  hadith('hadith', 'Hadith'),
  autres('autres', 'Autres');

  const AudioShelf(this.id, this.label);

  final String id;
  final String label;

  static AudioShelf? byId(String id) {
    for (final shelf in values) {
      if (shelf.id == id) return shelf;
    }
    return null;
  }
}

AudioShelf shelfOf(Track track) {
  final title = foldTitle(track.title);
  if (RegExp(r'ziarat|zyarat|zyaar').hasMatch(title)) {
    return AudioShelf.zyaraate;
  }
  if (RegExp(r'hadith|hadis|hadic').hasMatch(title)) return AudioShelf.hadith;
  if (_isAamal(title)) return AudioShelf.aamal;
  if (RegExp(r'doua|mounajat|salawat|salat').hasMatch(title)) {
    return AudioShelf.doua;
  }
  return AudioShelf.autres;
}

List<Track> tracksOf(AudioShelf shelf, Iterable<Track> tracks) {
  final items = tracks.where((track) => shelfOf(track) == shelf).toList();
  items.sort(compareAudioTitles);
  return items;
}

int compareAudioTitles(Track a, Track b) {
  final dayA = ramadanDay(a.title);
  final dayB = ramadanDay(b.title);
  if (dayA != null || dayB != null) {
    if (dayA == null) return 1;
    if (dayB == null) return -1;
    final byDay = dayA.compareTo(dayB);
    if (byDay != 0) return byDay;
  }
  final weekA = weekdayOrder(a.title);
  final weekB = weekdayOrder(b.title);
  if (weekA != null || weekB != null) {
    if (weekA == null) return 1;
    if (weekB == null) return -1;
    final byWeek = weekA.compareTo(weekB);
    if (byWeek != 0) return byWeek;
  }
  return foldTitle(a.title).compareTo(foldTitle(b.title));
}

int? ramadanDay(String title) {
  final folded = foldTitle(title);
  if (!folded.contains('ramzan')) return null;
  final match = RegExp(r'(\d+)').firstMatch(folded);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? weekdayOrder(String title) {
  final folded = foldTitle(title);
  const days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  for (var i = 0; i < days.length; i++) {
    if (folded.contains(days[i])) return i;
  }
  return null;
}

bool _isAamal(String title) => RegExp(
  r'ramzan|shaban|sehri|jour de l.?an|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche',
).hasMatch(title);

String foldTitle(String value) {
  const pairs = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    '’': "'",
    '‘': "'",
  };
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(pairs[char] ?? char);
  }
  return buffer.toString();
}
