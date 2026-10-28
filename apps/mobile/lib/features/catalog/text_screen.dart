import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/store.dart';
import '../../core/track.dart';
import '../../ui/site.dart';
import '../duas/dua.dart';
import 'jawshan.dart';
import '../downloads/download_controller.dart';
import '../player/audio_controller.dart';
import '../reader/content_install.dart';
import '../reader/page_history.dart';
import '../reader/reader_screen.dart';

enum TextPane { arabic, translation, transliteration, gujarati }

TextPane _openingPane(DevotionalText item) {
  if (item.hasArabic || item.hasOriginalPage) return TextPane.arabic;
  if (item.hasTranslation) return TextPane.translation;
  return TextPane.transliteration;
}

const _fontKey = 'readingFonts';
const _arabicMin = 20.0;
const _arabicMax = 48.0;
const _proseMin = 14.0;
const _proseMax = 32.0;

/// Un seul cran pour les quatre lectures. L’arabe reste plus grand.
const _textSizeLevels = <_TextSizeLevel>[
  _TextSizeLevel('Petit', 24, 16),
  _TextSizeLevel('Normal', 28, 18),
  _TextSizeLevel('Grand', 34, 22),
  _TextSizeLevel('Très grand', 40, 26),
  _TextSizeLevel('Énorme', 46, 30),
];

class _TextSizeLevel {
  const _TextSizeLevel(this.name, this.arabic, this.prose);
  final String name;
  final double arabic;
  final double prose;
}

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
    this.downloads,
    this.tracks = const [],
    this.store,
    this.opensUpdatedText,
    this.jawshanTitles,
  });

  final DevotionalText item;
  final LocalEdition edition;
  final bool favorite;
  final Future<void> Function() onFavorite;
  final PerlesAudioHandler? audio;
  final DownloadController? downloads;
  final List<Track> tracks;
  final AppStore? store;

  /// Vrai pour une sourate dont la lecture native remplace l’ancienne page.
  final bool Function(String id)? opensUpdatedText;

  /// Titres déjà chargés. Sinon, Jawshan les lit dans l’asset au démarrage.
  final List<JawshanTitle>? jawshanTitles;

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  final _scroll = ScrollController();
  final _readerKey = GlobalKey<ReaderScreenState>();
  final _surahInfoKey = GlobalKey();
  bool _surahInfoOpen = false;
  double arabicSize = 28;
  double translationSize = 18;
  double transliterationSize = 18;
  double gujaratiSize = 18;
  bool _customSizes = false;
  int _levelIndex = 1;
  late bool favorite = widget.favorite;
  late TextPane pane;
  bool _pageHistory = false;
  int? _jawshanPart;
  List<JawshanTitle> _jawshanTitles = const [];
  List<GlobalKey> _jawshanKeys = const [];

  @override
  void initState() {
    super.initState();
    pane = _openingPane(widget.item);
    unawaited(_loadSizes());
    if (isJawshanKabirId(widget.item.id)) {
      _jawshanKeys = List<GlobalKey>.generate(100, (_) => GlobalKey());
      final provided = widget.jawshanTitles;
      if (provided != null) {
        _jawshanTitles = provided;
      } else {
        unawaited(_loadJawshanTitles());
      }
    }
  }

  @override
  void didUpdateWidget(TextScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favorite != widget.favorite) favorite = widget.favorite;
    if (!widget.item.hasGujarati && pane == TextPane.gujarati) {
      pane = _openingPane(widget.item);
    }
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
      gujaratiSize = _savedSize(
        saved['gujarati'],
        _proseMin,
        _proseMax,
        gujaratiSize,
      );
      _levelIndex = _nearestLevelIndex();
    });
  }

  double _savedSize(Object? value, double min, double max, double fallback) {
    final number = value is num ? value.toDouble() : fallback;
    return number.clamp(min, max).toDouble();
  }

  int _nearestLevelIndex() {
    var best = 0;
    var bestScore = double.infinity;
    for (var index = 0; index < _textSizeLevels.length; index++) {
      final level = _textSizeLevels[index];
      final score =
          (arabicSize - level.arabic).abs() +
          (translationSize - level.prose).abs() +
          (transliterationSize - level.prose).abs() +
          (gujaratiSize - level.prose).abs();
      if (score < bestScore) {
        bestScore = score;
        best = index;
      }
    }
    return best;
  }

  void _stepLevel(int delta) {
    final next = _levelIndex + delta;
    if (next < 0 || next >= _textSizeLevels.length) return;
    final fraction = _readingFraction();
    final level = _textSizeLevels[next];
    setState(() {
      _customSizes = true;
      _levelIndex = next;
      arabicSize = level.arabic;
      translationSize = level.prose;
      transliterationSize = level.prose;
      gujaratiSize = level.prose;
    });
    final store = widget.store;
    if (store != null) {
      unawaited(
        store.writeState(_fontKey, {
          'arabic': arabicSize,
          'translation': translationSize,
          'transliteration': transliterationSize,
          'gujarati': gujaratiSize,
        }),
      );
    }
    _restoreReadingFraction(fraction);
  }

  double? _readingFraction() {
    if (!_scroll.hasClients) return null;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    if (!max.isFinite || max <= 0) return 0;
    return (position.pixels / max).clamp(0.0, 1.0);
  }

  void _restoreReadingFraction(double? fraction) {
    if (fraction == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final max = position.maxScrollExtent;
      if (!max.isFinite || max <= 0) return;
      final target = (fraction * max).clamp(0.0, max);
      if ((position.pixels - target).abs() < 1) return;
      position.jumpTo(target);
    });
  }

  void _setPageHistory(bool value) {
    if (!mounted || _pageHistory == value) return;
    setState(() => _pageHistory = value);
  }

  bool _showsOriginal(TextPane value) =>
      value == TextPane.arabic && widget.item.hasOriginalPage;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return PageBackScope(
      hasPageHistory: _pageHistory,
      onPageBack: () {
        final reader = _readerKey.currentState;
        if (reader == null) return;
        unawaited(reader.goBack());
      },
      child: Scaffold(
        backgroundColor: siteCanvas,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SiteReaderHeader(
              title: item.title,
              favorite: favorite,
              onBack: () => Navigator.of(context).maybePop(),
              onHome: () => GoRouter.maybeOf(context)?.go('/sommaire'),
              onScrollToTop: _scrollToTop,
              onPlay: _play,
              onDownload: widget.downloads == null || widget.tracks.isEmpty
                  ? null
                  : _download,
              onFavorite: () async {
                await widget.onFavorite();
                if (mounted) setState(() => favorite = !favorite);
              },
              onShare: _share,
            ),
            Expanded(
              child: IosReadingBackEdge(
                enabled: _pageHistory,
                child: _pane(item),
              ),
            ),
            _textSizeBar(),
            SiteTextTabs(
              selected: pane.index,
              labels: [
                'Arabic',
                'Translation',
                'Transliteration',
                if (item.hasGujarati) 'Gujarati',
              ],
              onSelected: (index) {
                setState(() {
                  pane = TextPane.values[index];
                  if (!_showsOriginal(pane)) _pageHistory = false;
                });
                final part = _jawshanPart;
                if (isJawshanKabirId(item.id) && part != null) {
                  _revealJawshanPart(part);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _textSizeBar() {
    if (pane == TextPane.arabic && widget.item.hasOriginalPage) {
      return const _OriginalPageHint();
    }
    final atMin = _levelIndex <= 0;
    final atMax = _levelIndex >= _textSizeLevels.length - 1;
    final label = atMin
        ? 'Taille minimale'
        : atMax
        ? 'Taille maximale'
        : _textSizeLevels[_levelIndex].name;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Taille du texte',
      child: Material(
        key: const Key('text-size-bar'),
        color: const Color(0xFFF7F8F4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD9E3C8))),
          ),
          child: SizedBox(
            height: siteReaderBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: _sizeStep(
                      key: const Key('smaller-text'),
                      lines: const ['A−', 'Plus petit'],
                      tooltip: 'Plus petit',
                      semantics: atMin
                          ? 'Plus petit, taille minimale'
                          : 'Plus petit',
                      enabled: !atMin,
                      onPressed: () => _stepLevel(-1),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: siteText(
                              color: siteBlack,
                              fontSize: 13,
                              lineHeight: 16,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _sizeStep(
                      key: const Key('larger-text'),
                      lines: const ['A+', 'Plus grand'],
                      tooltip: 'Plus grand',
                      semantics: atMax
                          ? 'Plus grand, taille maximale'
                          : 'Plus grand',
                      enabled: !atMax,
                      onPressed: () => _stepLevel(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeStep({
    required Key key,
    required List<String> lines,
    required String tooltip,
    required String semantics,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final style = siteText(
      color: enabled ? Colors.white : const Color(0xFF616161),
      fontSize: 14,
      lineHeight: 16,
      weight: FontWeight.w700,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semantics,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: enabled ? siteGreenSolid : const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: key,
                onTap: enabled ? onPressed : null,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final line in lines) Text(line, style: style),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openUpdatedText(String id) {
    if (widget.opensUpdatedText?.call(id) != true) return;
    GoRouter.maybeOf(context)?.push('/text/$id');
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

  Future<void> _download() async {
    final downloads = widget.downloads;
    if (downloads == null || widget.tracks.isEmpty) return;
    await downloads.enqueue(widget.tracks, individual: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Téléchargement lancé pour l’écoute hors ligne.'),
      ),
    );
  }

  Widget _pane(DevotionalText item) {
    if (isJawshanKabirId(item.id)) return _jawshanReading(item);
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
              opensUpdatedText: widget.opensUpdatedText,
              onOpenUpdatedText: _openUpdatedText,
              onOpenAppSommaire: () =>
                  GoRouter.maybeOf(context)?.go('/sommaire'),
              onPageHistory: _setPageHistory,
            ),
          );
        }
        if (item.hasArabic) {
          return _reading(
            _hadith(item.introduction),
            item.arabic,
            const [],
            rtl: true,
            surahInfo: item.kind == DevotionalKind.quran
                ? _surahInfo(item.translation)
                : null,
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
          translationVerses: item.kind == DevotionalKind.quran,
          surahInfo: item.kind == DevotionalKind.quran
              ? _surahInfo(item.translation)
              : null,
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
      case TextPane.gujarati:
        if (!item.hasGujarati) {
          return _empty('Gujarati non disponible');
        }
        return _reading('', item.gujarati, const [], gujarati: true);
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

  TextStyle _gujaratiStyle(double size) => TextStyle(
    fontFamily: 'NotoSansGujarati',
    fontFamilyFallback: const [
      'Noto Sans Gujarati',
      'Noto Sans',
      ...siteSansFallbacks,
    ],
    color: siteBlack,
    fontSize: size,
    height: 1.85,
    fontWeight: FontWeight.w400,
  );

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

  void _revealSurahInfo() {
    final opening = !_surahInfoOpen;
    setState(() => _surahInfoOpen = opening);
    if (!opening) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _surahInfoKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    });
  }

  Widget _surahInfoLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: TextButton(
          onPressed: _revealSurahInfo,
          style: TextButton.styleFrom(
            foregroundColor: siteLink,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Infos sur la sourate',
            textAlign: TextAlign.center,
            style:
                siteText(
                  color: siteLink,
                  fontSize: 16,
                  lineHeight: 22,
                  weight: FontWeight.w600,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: siteLink,
                ),
          ),
        ),
      ),
    );
  }

  Widget _reading(
    String? introduction,
    String body,
    List<String> references, {
    bool rtl = false,
    bool verses = false,
    bool translationVerses = false,
    bool gujarati = false,
    String? surahInfo,
  }) {
    final text = body.trim();
    final intro = introduction?.trim() ?? '';
    if (text.isEmpty && intro.isEmpty && references.isEmpty) {
      return _empty(
        'Ce passage n’est pas en texte dans la page source. Ouvrez l’onglet Arabic pour la version originale.',
      );
    }
    final proseSize = gujarati
        ? gujaratiSize
        : verses
        ? transliterationSize
        : translationSize;
    final infoCut = surahInfo == null ? null : _surahInfoStart(text);
    final verseBody = infoCut == null
        ? text
        : text.substring(0, infoCut).trim();
    final translated = translationVerses ? _numberedTranslation(text) : null;
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
            if (surahInfo != null) _surahInfoLink(),
            if (surahInfo != null && _surahInfoOpen)
              Padding(
                key: _surahInfoKey,
                padding: const EdgeInsets.only(bottom: 16),
                child: _InfoCard(
                  text: surahInfo,
                  size: proseSize,
                  title: 'Infos sur la sourate',
                ),
              ),
            if (intro.isNotEmpty && text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InfoCard(text: intro, size: proseSize),
              )
            else if (intro.isNotEmpty) ...[
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
                          ? _ruledBlack(_arabicStyle())
                          : siteText(
                              color: siteBlack,
                              fontSize: proseSize,
                              lineHeight: proseSize * 1.4,
                              weight: FontWeight.w700,
                            ),
                    ),
                  ),
            ] else if (text.isNotEmpty && gujarati) ...[
              for (final paragraph in text.split(RegExp(r'\n{2,}')))
                if (paragraph.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      paragraph.trim(),
                      textAlign: TextAlign.start,
                      style: _gujaratiStyle(proseSize),
                    ),
                  ),
            ] else if (translated != null) ...[
              for (final line in translated.lines)
                _verseLine(line, proseSize, italic: false),
            ] else if (text.isNotEmpty && verses) ...[
              for (final line in _verseLines(
                widget.item.kind == DevotionalKind.quran
                    ? widget.item.arabic
                    : '',
                text,
                numbered: widget.item.kind == DevotionalKind.quran,
              ))
                _verseLine(line, proseSize, italic: true),
            ] else if (verseBody.isNotEmpty) ...[
              for (final paragraph in _paragraphs(verseBody))
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

  Widget _verseLine(_Line line, double size, {required bool italic}) {
    final style = siteText(
      color: siteBlack,
      fontSize: size,
      lineHeight: size * 1.35,
    ).copyWith(fontStyle: italic ? FontStyle.italic : FontStyle.normal);
    final number = line.number;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            if (number != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: _AyahBadge(
                    number: number,
                    diameter: _badgeSize(size, number),
                    western: true,
                  ),
                ),
              ),
            TextSpan(text: line.text),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _share() async {
    final item = widget.item;
    final body = pane == TextPane.gujarati && item.hasGujarati
        ? item.gujarati
        : item.hasTranslation
        ? item.translation
        : item.hasTransliteration
        ? item.transliteration
        : item.title;
    await SharePlus.instance.share(
      ShareParams(text: '${item.title}\n\n$body', title: item.title),
    );
  }

  Future<void> _loadJawshanTitles() async {
    final titles = await loadJawshanTitles();
    if (!mounted) return;
    setState(() => _jawshanTitles = titles);
  }

  String _jawshanFrench(int number) {
    for (final title in _jawshanTitles) {
      if (title.number == number) return title.french;
    }
    return '';
  }

  void _revealJawshanPart(int number) {
    if (number < 1 || number > _jawshanKeys.length) return;
    setState(() => _jawshanPart = number);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _jawshanKeys[number - 1].currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: Duration.zero,
        alignment: 0,
      );
    });
  }

  double get _jawshanHeaderSize => switch (pane) {
    TextPane.arabic || TextPane.translation => translationSize,
    TextPane.transliteration => transliterationSize,
    TextPane.gujarati => gujaratiSize,
  };

  Widget _jawshanReading(DevotionalText item) {
    final hadith = jawshanHadith(_hadith(item.introduction));
    final headerSize = _jawshanHeaderSize;
    final List<String> blocks;
    var preamble = '';
    switch (pane) {
      case TextPane.arabic:
        blocks = jawshanBlocks(item.arabic);
      case TextPane.transliteration:
        blocks = jawshanBlocks(item.transliteration);
      case TextPane.translation:
        final parsed = parseJawshanTranslation(item.translation);
        if (parsed == null) return _fallbackJawshan(item);
        preamble = parsed.preamble;
        blocks = parsed.parts;
      case TextPane.gujarati:
        return _reading('', item.gujarati, const [], gujarati: true);
    }
    if (blocks.length != 100 || _jawshanKeys.length != 100) {
      return _fallbackJawshan(item);
    }
    return ColoredBox(
      color: siteCanvas,
      child: SelectionArea(
        child: SingleChildScrollView(
          key: const Key('jawshan-reading'),
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                item.title.toUpperCase(),
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
            if (hadith.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InfoCard(text: hadith, size: headerSize),
              ),
            _jawshanToc(headerSize),
            if (preamble.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(
                  preamble,
                  textAlign: TextAlign.start,
                  style: siteText(
                    color: siteBlack,
                    fontSize: headerSize,
                    lineHeight: headerSize * 1.4,
                  ),
                ),
              ),
            for (var i = 0; i < blocks.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 28,
                  thickness: 1,
                  color: Color(0xFFB7C7A4),
                ),
              _jawshanHeader(i + 1, headerSize),
              ..._jawshanBody(blocks[i], headerSize),
            ],
            // Laisse la dernière partie atteindre le haut de l’écran.
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.55),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackJawshan(DevotionalText item) {
    final hadith = _hadith(item.introduction);
    return switch (pane) {
      TextPane.arabic => _reading(hadith, item.arabic, const [], rtl: true),
      TextPane.translation => _reading(hadith, item.translation, item.references),
      TextPane.transliteration => _reading(
        hadith,
        item.transliteration,
        const [],
        verses: true,
      ),
      TextPane.gujarati => _reading('', item.gujarati, const [], gujarati: true),
    };
  }

  Widget _jawshanToc(double size) {
    final style = siteText(
      color: siteBlack,
      fontSize: size,
      lineHeight: size * 1.35,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E3C8)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          key: const Key('jawshan-toc'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var number = 1; number <= 100; number++)
                InkWell(
                  key: Key('jawshan-toc-$number'),
                  onTap: () => _revealJawshanPart(number),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Text('Doua - $number', style: style),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jawshanHeader(int number, double size) {
    final french = _jawshanFrench(number);
    return Padding(
      key: _jawshanKeys[number - 1],
      padding: const EdgeInsets.only(top: 18, bottom: 16),
      child: Column(
        children: [
          Text(
            'Doua - $number',
            textAlign: TextAlign.center,
            style: siteText(
              color: siteGreenSolid,
              fontSize: size,
              lineHeight: size * 1.3,
              weight: FontWeight.w700,
            ),
          ),
          if (french.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              french,
              textAlign: TextAlign.center,
              style: siteText(
                color: siteBlack,
                fontSize: size,
                lineHeight: size * 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _jawshanBody(String block, double size) {
    switch (pane) {
      case TextPane.arabic:
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              block.trim(),
              textDirection: _arabicScript(block)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              textAlign: TextAlign.center,
              style: _arabicScript(block)
                  ? _ruledBlack(_arabicStyle())
                  : siteText(
                      color: siteBlack,
                      fontSize: size,
                      lineHeight: size * 1.4,
                      weight: FontWeight.w700,
                    ),
            ),
          ),
        ];
      case TextPane.transliteration:
        return [
          for (final raw in block.split(RegExp(r'\n+')))
            if (raw.trim().isNotEmpty)
              _verseLine(_Line(raw.trim()), size, italic: true),
        ];
      case TextPane.translation:
        return [
          for (final paragraph in _paragraphs(block))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                paragraph,
                textAlign: TextAlign.start,
                style: siteText(
                  color: siteBlack,
                  fontSize: size,
                  lineHeight: size * 1.4,
                ),
              ),
            ),
        ];
      case TextPane.gujarati:
        return const [];
    }
  }
}

class _OriginalPageHint extends StatelessWidget {
  const _OriginalPageHint();

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('text-size-bar'),
      color: const Color(0xFFF7F8F4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD9E3C8))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: Text(
                'Pour agrandir cette page, écartez deux doigts',
                textAlign: TextAlign.center,
                style: siteText(
                  color: siteBlack,
                  fontSize: 16,
                  lineHeight: 22,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Line {
  const _Line(this.text, [this.number]);
  final String text;
  final int? number;
}

String? _surahInfo(String translation) {
  final text = translation.trim();
  final start = _surahInfoStart(text);
  if (start == null) return null;
  const marker = 'Infos sur la sourate';
  if (text.startsWith(marker, start)) {
    final body = text.substring(start + marker.length).trim();
    return body.isEmpty ? null : body;
  }
  final body = text.substring(start).trim();
  return body.isEmpty ? null : body;
}

int? _surahInfoStart(String text) {
  const marker = 'Infos sur la sourate';
  final marked = text.indexOf(marker);
  if (marked >= 0) return marked;
  const title = 'La traduction du titre de la Sourate';
  final alt = text.indexOf(title);
  if (alt <= 0) return null;
  var start = alt;
  final previous = text.substring(0, alt).trimRight().split(RegExp(r'\n{2,}'));
  if (previous.isNotEmpty) {
    final note = previous.last.trim();
    if (note.isNotEmpty && !RegExp(r'(^|\s)\d{1,3}\.\s*').hasMatch(note)) {
      final at = text.lastIndexOf(note, alt);
      if (at >= 0) start = at;
    }
  }
  return start;
}

class _ParsedTranslation {
  const _ParsedTranslation(this.lines, this.tail);
  final List<_Line> lines;
  final String tail;
}

_ParsedTranslation? _numberedTranslation(String body) {
  final text = body.trim();
  if (text.isEmpty) return null;
  final cut = _surahInfoStart(text);
  final head = cut == null ? text : text.substring(0, cut).trim();
  final tail = cut == null ? '' : text.substring(cut).trim();
  final matches = RegExp(r'(^|\s)(\d{1,3})\.\s*').allMatches(head).toList();
  if (matches.isEmpty) return null;
  final numbers = matches.map((match) => int.parse(match.group(2)!)).toList();
  for (var i = 1; i < numbers.length; i++) {
    if (numbers[i] != numbers[i - 1] + 1) return null;
  }
  final lines = <_Line>[];
  final preamble = head.substring(0, matches.first.start).trim();
  if (preamble.isNotEmpty) lines.add(_Line(preamble));
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : head.length;
    final verse = head.substring(start, end).trim();
    if (verse.isEmpty) continue;
    lines.add(_Line(verse, numbers[i]));
  }
  return lines.isEmpty ? null : _ParsedTranslation(lines, tail);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text, required this.size, this.title});

  final String text;
  final double size;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final blocks = text
        .split(RegExp(r'\n{2,}'))
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty);
    final heading = title?.trim() ?? '';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E3C8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading.isNotEmpty) ...[
              Text(
                heading,
                style: siteText(
                  color: siteGreen,
                  fontSize: size + 1,
                  lineHeight: (size + 1) * 1.3,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final block in blocks) _block(block),
          ],
        ),
      ),
    );
  }

  Widget _block(String block) {
    final body = siteText(
      color: siteBlack,
      fontSize: size,
      lineHeight: size * 1.4,
    );
    final heading = siteText(
      color: siteGreen,
      fontSize: size,
      lineHeight: size * 1.35,
      weight: FontWeight.w700,
    );
    final split = block.indexOf(':');
    final lineBreak = block.indexOf('\n');
    final labelEndsHere =
        split > 0 && split < 90 && (lineBreak < 0 || split < lineBreak);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: labelEndsHere
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(block.substring(0, split + 1), style: heading),
                if (block.substring(split + 1).trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(block.substring(split + 1).trim(), style: body),
                ],
              ],
            )
          : Text(block, style: body),
    );
  }
}

TextStyle _ruledBlack(TextStyle style) => style.copyWith(
  decoration: TextDecoration.underline,
  decorationColor: siteBlack,
  decorationThickness: 1.15,
);

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

double _badgeSize(double textSize, int number) {
  final digits = '$number'.length;
  final factor = digits >= 3
      ? 1.9
      : digits == 2
      ? 1.45
      : 1.2;
  return (textSize * factor).clamp(24.0, 64.0);
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
    if (lines.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final opening = _isBasmala(lines.first.text) ? lines.first : null;
    final body = opening == null ? lines : lines.sublist(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (opening != null)
            _ruledArabic(
              lines: [opening],
              scaler: scaler,
              align: TextAlign.center,
              flowKey: const Key('quran-basmala'),
            ),
          if (opening != null && body.isNotEmpty) const SizedBox(height: 18),
          if (body.isNotEmpty)
            _ruledArabic(
              lines: body,
              scaler: scaler,
              align: TextAlign.right,
              flowKey: const Key('quran-flow'),
            ),
        ],
      ),
    );
  }

  Widget _ruledArabic({
    required List<_Line> lines,
    required TextScaler scaler,
    required TextAlign align,
    required Key flowKey,
  }) {
    final placeholders = <PlaceholderDimensions>[];
    final span = TextSpan(
      style: style,
      children: [
        for (var i = 0; i < lines.length; i++)
          ..._ayahSpans(
            lines[i],
            spaced: i > 0,
            style: style,
            scaler: scaler,
            placeholders: placeholders,
          ),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: _QuranLineRulesPainter(
          span: span,
          textScaler: scaler,
          placeholders: placeholders,
          textAlign: align,
        ),
        child: Text.rich(
          span,
          key: flowKey,
          style: style,
          textDirection: TextDirection.rtl,
          textAlign: align,
          textWidthBasis: TextWidthBasis.parent,
          textScaler: scaler,
        ),
      ),
    );
  }
}

bool _isBasmala(String text) {
  final compact = text.replaceAll(
    RegExp(
      r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200C\u200D\s\uE000-\uF8FF]',
    ),
    '',
  );
  return compact.startsWith('بسم') && compact.length <= 24;
}

List<InlineSpan> _ayahSpans(
  _Line line, {
  required bool spaced,
  required TextStyle style,
  required TextScaler scaler,
  required List<PlaceholderDimensions> placeholders,
}) {
  final lead = spaced ? ' ' : '';
  final number = line.number;
  if (number == null) return [TextSpan(text: '$lead${line.text}')];
  // Flutter coupe avant un WidgetSpan même après U+2060. Le dernier mot
  // voyage donc avec le médaillon : le collage reste dans ce bloc.
  final split = _lastWord(line.text);
  final diameter = _badgeDiameter(style, number);
  placeholders.add(
    PlaceholderDimensions(
      size: _tailSize(split.word, style, scaler, diameter),
      alignment: PlaceholderAlignment.middle,
    ),
  );
  final before = '$lead${split.before}';
  return [
    TextSpan(
      children: [
        if (before.isNotEmpty) TextSpan(text: before),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Row(
            key: ValueKey('ayah-tail-$number'),
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${split.word}\u2060',
                key: ValueKey('ayah-word-$number'),
                style: style,
                textDirection: TextDirection.rtl,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: _AyahBadge(number: number, diameter: diameter),
              ),
            ],
          ),
        ),
      ],
    ),
  ];
}

({String before, String word}) _lastWord(String text) {
  final match = RegExp(r'^(.*\s)(\S+)\s*$').firstMatch(text);
  if (match == null) return (before: '', word: text.trim());
  return (before: match.group(1)!, word: match.group(2)!);
}

Size _tailSize(
  String word,
  TextStyle style,
  TextScaler scaler,
  double diameter,
) {
  final painter = TextPainter(
    text: TextSpan(text: '$word\u2060', style: style),
    textDirection: TextDirection.rtl,
    textScaler: scaler,
  )..layout();
  final size = Size(
    painter.width + 4 + diameter,
    math.max(painter.height, diameter),
  );
  painter.dispose();
  return size;
}

double _badgeDiameter(TextStyle style, int number) {
  final digits = '$number'.length;
  return ((style.fontSize ?? 28) * (digits >= 3 ? 1.4 : 0.9)).clamp(26.0, 64.0);
}

/// Étend le trait à tous les glyphes de la ligne, y compris le médaillon.
@visibleForTesting
({double left, double right}) quranRuleEdges({
  required double metricLeft,
  required double metricWidth,
  required double lineTop,
  required double lineBottom,
  required List<TextBox> boxes,
}) {
  var left = metricLeft;
  var right = metricLeft + math.max(0, metricWidth);
  for (final box in boxes) {
    final mid = (box.top + box.bottom) / 2;
    if (mid < lineTop - 1 || mid >= lineBottom + 1) continue;
    if (box.right - box.left < 0.5) continue;
    left = math.min(left, box.left);
    right = math.max(right, box.right);
  }
  return (left: left, right: right);
}

/// Trait gris sous toute la ligne rendue, du premier au dernier glyphe.
class _QuranLineRulesPainter extends CustomPainter {
  _QuranLineRulesPainter({
    required this.span,
    required this.textScaler,
    required this.placeholders,
    required this.textAlign,
  });

  final TextSpan span;
  final TextScaler textScaler;
  final List<PlaceholderDimensions> placeholders;
  final TextAlign textAlign;

  static const _rule = Color(0xFF8A8A8A);

  TextPainter _layout(double width) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      textWidthBasis: TextWidthBasis.parent,
      textScaler: textScaler,
    );
    painter.setPlaceholderDimensions(placeholders);
    painter.layout(maxWidth: math.max(0, width));
    return painter;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final painter = _layout(size.width);
    final paint = Paint()
      ..color = _rule
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    try {
      final metrics = painter.computeLineMetrics();
      final plain = painter.text?.toPlainText() ?? '';
      final boxes = plain.isEmpty
          ? const <TextBox>[]
          : painter.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: plain.length),
            );
      final gap = (span.style?.fontSize ?? 28) * 0.55;
      for (final line in metrics) {
        final edges = quranRuleEdges(
          metricLeft: line.left,
          metricWidth: line.width,
          lineTop: line.baseline - line.ascent,
          lineBottom: line.baseline + line.descent,
          boxes: boxes,
        );
        final y = line.baseline + gap;
        if (y < 0 || y > size.height || edges.right - edges.left < 1) {
          continue;
        }
        canvas.drawLine(
          Offset(edges.left, y),
          Offset(edges.right, y),
          paint,
        );
      }
    } finally {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _QuranLineRulesPainter oldDelegate) {
    return oldDelegate.span.toPlainText() != span.toPlainText() ||
        oldDelegate.span.style != span.style ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.placeholders.length != placeholders.length;
  }
}

class _AyahBadge extends StatelessWidget {
  const _AyahBadge({
    required this.number,
    required this.diameter,
    this.western = false,
  });

  final int number;
  final double diameter;
  final bool western;

  @override
  Widget build(BuildContext context) {
    final label = western ? '$number' : _indoDigits(number);
    final digits = '$number'.length;
    final fontSize =
        diameter *
        (digits >= 3
            ? 0.34
            : digits == 2
            ? (western ? 0.46 : 0.78)
            : (western ? 0.58 : 0.92));
    final style = western
        ? siteText(
            color: _ayahGold,
            fontSize: fontSize,
            lineHeight: fontSize,
            weight: FontWeight.w700,
          )
        : TextStyle(
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
          );
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
              overflow: TextOverflow.visible,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: style,
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
