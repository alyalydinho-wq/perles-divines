import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/store.dart';
import '../../core/track.dart';
import '../../ui/site.dart';
import '../duas/dua.dart';
import '../player/audio_controller.dart';
import '../reader/content_install.dart';
import '../reader/reader_screen.dart';

enum TextPane { arabic, translation, transliteration }

const _fontKey = 'readingFonts';
const _arabicMin = 20.0;
const _arabicMax = 48.0;
const _proseMin = 14.0;
const _proseMax = 32.0;

/// L’encre de la police IndoPak occupe environ 2,04 em. En dessous, les
/// voyelles de deux lignes se touchent ; au-dessus, ce n’est que du vide.
const _arabicLineHeight = 2.06;

const _ayahGold = Color(0xFFC6A15A);

/// Les chiffres arabes-indiens (U+0660) d’IndoPak ont une chasse nulle :
/// ils doivent se poser dans l’ornement ﴿ ﴾, ce que le rendu Flutter ne fait
/// pas. On retire donc le marqueur du texte et on redessine le numéro.
final _ayahMarker = RegExp(r'\s*﴿\s*([0-9٠-٩۰-۹]+)\s*﴾\s*$');

class TextScreen extends StatefulWidget {
  const TextScreen({
    super.key,
    required this.item,
    required this.edition,
    required this.favorite,
    required this.onFavorite,
    this.audio,
    this.tracks = const [],
    this.store,
  });

  final DevotionalText item;
  final LocalEdition edition;
  final bool favorite;
  final Future<void> Function() onFavorite;
  final PerlesAudioHandler? audio;
  final List<Track> tracks;
  final AppStore? store;

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  final _scroll = ScrollController();
  final _readerKey = GlobalKey<ReaderScreenState>();
  double arabicSize = 28;
  double translationSize = 18;
  double transliterationSize = 18;
  bool _customSizes = false;
  bool _sizesOpen = false;
  late bool favorite = widget.favorite;
  TextPane pane = TextPane.translation;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSizes());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSizes() async {
    final store = widget.store;
    if (store == null) return;
    final saved = await store.readState(_fontKey);
    if (!mounted || _customSizes || saved is! Map) return;
    setState(() {
      arabicSize = _savedSize(
        saved['arabic'],
        _arabicMin,
        _arabicMax,
        arabicSize,
      );
      translationSize = _savedSize(
        saved['translation'],
        _proseMin,
        _proseMax,
        translationSize,
      );
      transliterationSize = _savedSize(
        saved['transliteration'],
        _proseMin,
        _proseMax,
        transliterationSize,
      );
    });
  }

  double _savedSize(Object? value, double min, double max, double fallback) {
    final number = value is num ? value.toDouble() : fallback;
    return number.clamp(min, max).toDouble();
  }

  void _setSizes({
    double? arabic,
    double? translation,
    double? transliteration,
  }) {
    setState(() {
      _customSizes = true;
      if (arabic != null) arabicSize = arabic;
      if (translation != null) translationSize = translation;
      if (transliteration != null) transliterationSize = transliteration;
    });
    final store = widget.store;
    if (store == null) return;
    unawaited(
      store.writeState(_fontKey, {
        'arabic': arabicSize,
        'translation': translationSize,
        'transliteration': transliterationSize,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: siteCanvas,
      body: Column(
        children: [
          SiteReaderHeader(
            title: item.title,
            favorite: favorite,
            onBack: () => Navigator.of(context).maybePop(),
            onPlay: _play,
            onFavorite: () async {
              await widget.onFavorite();
              if (mounted) setState(() => favorite = !favorite);
            },
            onShare: _share,
          ),
          _actionBar(),
          Expanded(child: _pane(item)),
          SiteTextTabs(
            selected: pane.index,
            onSelected: (index) =>
                setState(() => pane = TextPane.values[index]),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Column(
      children: [
        Material(
          color: siteGreenSolid,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _barButton(
                  tooltip: 'Taille du texte',
                  icon: Icons.settings,
                  selected: _sizesOpen,
                  onPressed: () => setState(() => _sizesOpen = !_sizesOpen),
                ),
                _barButton(
                  tooltip: 'Sommaire',
                  icon: Icons.home,
                  onPressed: () => GoRouter.maybeOf(context)?.go('/sommaire'),
                ),
                _barButton(
                  tooltip: 'Page précédente',
                  icon: Icons.chevron_left,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                _barButton(
                  tooltip: 'Haut de la page',
                  icon: Icons.keyboard_arrow_up,
                  onPressed: _scrollToTop,
                ),
              ],
            ),
          ),
        ),
        if (_sizesOpen) _fontControls(),
      ],
    );
  }

  Widget _barButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28, color: Colors.white),
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: selected ? const Color(0x33FFFFFF) : Colors.transparent,
        fixedSize: const Size(52, 44),
        shape: const CircleBorder(),
      ),
    );
  }

  void _scrollToTop() {
    final reader = _readerKey.currentState;
    if (reader != null) {
      unawaited(reader.scrollToTop());
      return;
    }
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _fontControls() {
    return Material(
      color: siteCanvas,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8F4),
          border: Border(bottom: BorderSide(color: Color(0xFFD9E3C8))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              _stepper(
                label: 'Arabe',
                value: arabicSize,
                min: _arabicMin,
                max: _arabicMax,
                step: 2,
                active: pane == TextPane.arabic,
                onChanged: (value) => _setSizes(arabic: value),
              ),
              const SizedBox(width: 6),
              _stepper(
                label: 'Traduction',
                value: translationSize,
                min: _proseMin,
                max: _proseMax,
                step: 1,
                active: pane == TextPane.translation,
                onChanged: (value) => _setSizes(translation: value),
              ),
              const SizedBox(width: 6),
              _stepper(
                label: 'Translit.',
                value: transliterationSize,
                min: _proseMin,
                max: _proseMax,
                step: 1,
                active: pane == TextPane.transliteration,
                onChanged: (value) => _setSizes(transliteration: value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required bool active,
    required ValueChanged<double> onChanged,
  }) {
    final target = switch (label) {
      'Arabe' => 'l’arabe',
      'Traduction' => 'la traduction',
      _ => 'la translittération',
    };
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE7F2D4) : siteCanvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? siteGreenSolid : const Color(0xFFD5D5D5),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 2, 4),
          child: Column(
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: siteText(
                  color: active ? siteGreen : const Color(0xFF5C5C5C),
                  fontSize: 11,
                  lineHeight: 13,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _sizeButton(
                    tooltip: 'Réduire $target',
                    icon: Icons.remove,
                    enabled: value > min,
                    onPressed: () => onChanged(math.max(min, value - step)),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${value.round()}',
                      textAlign: TextAlign.center,
                      style: siteText(
                        color: siteBlack,
                        fontSize: 14,
                        lineHeight: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _sizeButton(
                    tooltip: 'Agrandir $target',
                    icon: Icons.add,
                    enabled: value < max,
                    onPressed: () => onChanged(math.min(max, value + step)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeButton({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      style: IconButton.styleFrom(
        backgroundColor: enabled ? siteGreenSolid : const Color(0xFFE6E6E6),
        foregroundColor: enabled ? Colors.white : const Color(0xFF9A9A9A),
        disabledBackgroundColor: const Color(0xFFE6E6E6),
        disabledForegroundColor: const Color(0xFF9A9A9A),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 16),
    );
  }

  Future<void> _play() async {
    final audio = widget.audio;
    if (audio == null || widget.tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun audio n’est encore associé à ce texte.'),
        ),
      );
      return;
    }
    await audio.playTracks(widget.tracks);
  }

  Widget _pane(DevotionalText item) {
    switch (pane) {
      case TextPane.arabic:
        if (item.hasOriginalPage) {
          return ColoredBox(
            color: siteCanvas,
            child: ReaderScreen(
              key: _readerKey,
              edition: widget.edition,
              initialPage: item.pagePath,
              compact: true,
            ),
          );
        }
        if (item.hasArabic) {
          return _reading(
            _hadith(item.introduction),
            item.arabic,
            const [],
            rtl: true,
          );
        }
        return _empty(
          'L’arabe calligraphié n’est pas en texte Unicode dans la page source. La page originale n’est pas disponible ici.',
        );
      case TextPane.translation:
        return _reading(
          _hadith(item.introduction),
          item.translation,
          item.references,
        );
      case TextPane.transliteration:
        if (!item.hasTransliteration) {
          return _empty(
            'Aucune translittération n’est présente dans la page source.',
          );
        }
        return _reading(
          _hadith(item.introduction),
          item.transliteration,
          const [],
          verses: true,
        );
    }
  }

  bool _arabicScript(String value) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(value);

  String _hadith(String introduction) {
    final text = introduction.trim();
    final cut = text.indexOf('Réciter 100 fois');
    if (cut <= 0) return text;
    return text.substring(0, cut).trim();
  }

  List<String> _paragraphs(String value) {
    final paragraphs = <String>[];
    final sentence = RegExp(r'(?<=[.!?])\s+|(?<=,)\s+(?=Que la paix)');
    for (final block in value.split(RegExp(r'\n+'))) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      for (final piece in trimmed.split(sentence)) {
        final line = piece.trim();
        if (line.isNotEmpty) paragraphs.add(line);
      }
    }
    return paragraphs;
  }

  TextStyle _arabicStyle() => const TextStyle(
    fontFamily: 'Indopak',
    fontFamilyFallback: [
      'Noto Naskh Arabic',
      'Noto Sans Arabic',
      'Traditional Arabic',
      'Arial',
      ...siteSansFallbacks,
    ],
    color: siteBlack,
    height: _arabicLineHeight,
    fontWeight: FontWeight.w400,
  ).copyWith(fontSize: arabicSize);

  Widget _empty(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: siteText(color: siteBlack, fontSize: 16, lineHeight: 22),
      ),
    ),
  );

  Widget _reading(
    String? introduction,
    String body,
    List<String> references, {
    bool rtl = false,
    bool verses = false,
  }) {
    final text = body.trim();
    final intro = introduction?.trim() ?? '';
    if (text.isEmpty && intro.isEmpty && references.isEmpty) {
      return _empty(
        'Ce passage n’est pas en texte dans la page source. Ouvrez l’onglet Arabic pour la version originale.',
      );
    }
    final proseSize = verses ? transliterationSize : translationSize;
    return ColoredBox(
      color: siteCanvas,
      child: SelectionArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                widget.item.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: siteText(
                  color: siteGreenSolid,
                  fontSize: 16,
                  lineHeight: 22,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (intro.isNotEmpty) ...[
              Text(
                intro,
                style: siteText(
                  color: siteBlack,
                  fontSize: proseSize,
                  lineHeight: proseSize * 1.35,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
            ],
            if (text.isNotEmpty &&
                rtl &&
                widget.item.kind == DevotionalKind.quran)
              _QuranArabic(text: text, style: _arabicStyle())
            else if (text.isNotEmpty && rtl) ...[
              for (final block in text.split(RegExp(r'\n{2,}')))
                if (block.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      block.trim(),
                      textDirection: _arabicScript(block)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: _arabicScript(block)
                          ? _arabicStyle()
                          : siteText(
                              color: siteBlack,
                              fontSize: proseSize,
                              lineHeight: proseSize * 1.4,
                              weight: FontWeight.w700,
                            ),
                    ),
                  ),
            ] else if (text.isNotEmpty && verses) ...[
              for (final line in _verseLines(
                widget.item.kind == DevotionalKind.quran
                    ? widget.item.arabic
                    : '',
                text,
                numbered: widget.item.kind == DevotionalKind.quran,
              ))
                _transliterationLine(line, proseSize),
            ] else if (text.isNotEmpty) ...[
              for (final paragraph in _paragraphs(text))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    paragraph,
                    textAlign: TextAlign.start,
                    style: siteText(
                      color: siteBlack,
                      fontSize: proseSize,
                      lineHeight: proseSize * 1.4,
                    ),
                  ),
                ),
            ],
            for (final reference in references) ...[
              const SizedBox(height: 16),
              Text(
                reference,
                style: siteText(
                  color: siteBlack,
                  fontSize: proseSize,
                  lineHeight: proseSize * 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _transliterationLine(_Line line, double size) {
    final style = siteText(
      color: siteBlack,
      fontSize: size,
      lineHeight: size * 1.35,
    ).copyWith(fontStyle: FontStyle.italic);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.number != null)
            SizedBox(
              width: 32,
              child: Text(
                '${line.number}',
                textAlign: TextAlign.center,
                style: style.copyWith(
                  color: _ayahGold,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: Text(line.text, textAlign: TextAlign.center, style: style),
          ),
          if (line.number != null) const SizedBox(width: 32),
        ],
      ),
    );
  }

  Future<void> _share() async {
    final item = widget.item;
    final body = item.hasTranslation
        ? item.translation
        : item.hasTransliteration
        ? item.transliteration
        : item.title;
    await SharePlus.instance.share(
      ShareParams(text: '${item.title}\n\n$body', title: item.title),
    );
  }
}

class _Line {
  const _Line(this.text, [this.number]);
  final String text;
  final int? number;
}

List<_Line> _markedArabic(String value) {
  final lines = <_Line>[];
  for (final raw in value.split(RegExp(r'\n+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final match = _ayahMarker.firstMatch(line);
    if (match == null) {
      lines.add(_Line(line));
      continue;
    }
    final text = line.substring(0, match.start).trim();
    if (text.isEmpty) continue;
    lines.add(_Line(text, _digitsToInt(match.group(1)!)));
  }
  return lines;
}

List<_Line> _verseLines(String arabic, String body, {required bool numbered}) {
  final numbers = numbered
      ? _markedArabic(arabic).map((line) => line.number).toList()
      : const <int?>[];
  final lines = body
      .split(RegExp(r'\n+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return [
    for (var i = 0; i < lines.length; i++)
      _Line(lines[i], i < numbers.length ? numbers[i] : null),
  ];
}

int? _digitsToInt(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const extended = '۰۱۲۳۴۵۶۷۸۹';
  final western = value.split('').map((char) {
    final arabicIndex = arabic.indexOf(char);
    if (arabicIndex >= 0) return '$arabicIndex';
    final extendedIndex = extended.indexOf(char);
    if (extendedIndex >= 0) return '$extendedIndex';
    return RegExp(r'\d').hasMatch(char) ? char : '';
  }).join();
  return int.tryParse(western);
}

String _indoDigits(int value) {
  const extended = '۰۱۲۳۴۵۶۷۸۹';
  return '$value'.replaceAllMapped(
    RegExp(r'\d'),
    (match) => extended[int.parse(match[0]!)],
  );
}

class _QuranArabic extends StatelessWidget {
  const _QuranArabic({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = _markedArabic(text);
    final children = <Widget>[];
    final verses = <_Line>[];
    void flush() {
      if (verses.isEmpty) return;
      children.addAll([
        for (final verse in verses)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _AyahCell(line: verse, style: style),
          ),
      ]);
      verses.clear();
    }

    for (final line in lines) {
      if (line.number == null) {
        flush();
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              line.text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        );
      } else {
        verses.add(line);
      }
    }
    flush();
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _AyahCell extends StatelessWidget {
  const _AyahCell({required this.line, required this.style});

  final _Line line;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final diameter = ((style.fontSize ?? 28) * 1.2).clamp(34.0, 56.0);
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            line.text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        _AyahBadge(number: line.number!, diameter: diameter),
      ],
    );
  }
}

class _AyahBadge extends StatelessWidget {
  const _AyahBadge({required this.number, required this.diameter});

  final int number;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final label = _indoDigits(number);
    final fontSize =
        diameter *
        (label.length >= 3
            ? 0.62
            : label.length == 2
            ? 0.78
            : 0.92);
    return Semantics(
      label: 'Verset $number',
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CustomPaint(
          painter: const _OctagonPainter(),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Indopak',
                fontFamilyFallback: const [
                  'Noto Naskh Arabic',
                  'Noto Sans Arabic',
                  'Traditional Arabic',
                  'Arial',
                ],
                color: _ayahGold,
                fontSize: fontSize,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  const _OctagonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ayahGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(size, 1.4), stroke);
    canvas.drawPath(_path(size, size.shortestSide * 0.14), stroke);
  }

  Path _path(Size size, double inset) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - inset;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _OctagonPainter oldDelegate) => false;
}
