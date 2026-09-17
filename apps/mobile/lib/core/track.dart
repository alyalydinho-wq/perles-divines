class Track {
  const Track({
    required this.id,
    required this.title,
    required this.version,
    required this.durationMs,
    required this.sizeBytes,
    required this.sha256,
    required this.file,
    this.author,
    this.fixture = false,
  });
  final String id, title, sha256, file;
  final String? author;
  final int version, durationMs, sizeBytes;
  final bool fixture;
  String get transferId => '$id-v$version';
  factory Track.fromJson(Map<String, dynamic> j) => Track(
    id: j['id'],
    title: j['title'],
    version: j['version'],
    durationMs: j['durationMs'],
    sizeBytes: j['sizeBytes'],
    sha256: j['sha256'],
    file: j['file'],
    author: j['author'],
    fixture: j['fixture'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'version': version,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'file': file,
    'author': author,
    'fixture': fixture,
  };
}

String exportName(String title) {
  final clean = title
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  return '${clean.isEmpty ? 'audio' : clean.substring(0, clean.length.clamp(0, 120))}.mp3';
}

Duration restoredPosition(
  int savedMs,
  int durationMs, {
  bool completed = false,
}) => completed || savedMs < 0 || savedMs >= durationMs
    ? Duration.zero
    : Duration(milliseconds: savedMs);
