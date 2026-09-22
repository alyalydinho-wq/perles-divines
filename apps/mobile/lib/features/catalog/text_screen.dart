import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/track.dart';
import '../../ui/site.dart';
import '../duas/dua.dart';
import '../player/audio_controller.dart';
import '../reader/content_install.dart';
import '../reader/reader_screen.dart';

enum TextPane { arabic, translation, transliteration }

class TextScreen extends StatefulWidget {
  const TextScreen({
    super.key,
    required this.item,
    required this.edition,
    required this.favorite,
    required this.onFavorite,
    this.audio,
    this.tracks = const [],
    this.textScale = 1.1,
  });

  final DevotionalText item;
  final LocalEdition edition;
  final bool favorite;
  final Future<void> Function() onFavorite;
  final PerlesAudioHandler? audio;
  final List<Track> tracks;
  final double textScale;

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  late double scale = widget.textScale;
  late bool favorite = widget.favorite;
  TextPane pane = TextPane.translation;

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
              edition: widget.edition,
              initialPage: item.pagePath,
              compact: true,
            ),
          );
        }
        if (item.hasArabic) {
          return _reading(_hadith(item.introduction), item.arabic, const [], rtl: true);
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
    final sentence = RegExp(
      r'(?<=[.!?])\s+|(?<=,)\s+(?=Que la paix)',
    );
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
    return ColoredBox(
      color: siteCanvas,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                widget.item.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: siteText(
                  color: siteGreenSolid,
                  fontSize: 16 * scale,
                  lineHeight: 22,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (intro.isNotEmpty) ...[
              Text(
                intro,
                style: siteText(
                  color: siteBlack,
                  fontSize: 16 * scale,
                  lineHeight: 22,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 18),
            ],
            if (text.isNotEmpty && rtl) ...[
              for (final block in text.split(RegExp(r'\n{2,}')))
                if (block.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      block.trim(),
                      textDirection: _arabicScript(block)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: siteText(
                        color: siteBlack,
                        fontSize: (_arabicScript(block) ? 28 : 16) * scale,
                        lineHeight: (_arabicScript(block) ? 78 : 24) * scale,
                        weight: _arabicScript(block)
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ).copyWith(
                        fontFamily: _arabicScript(block) ? 'Indopak' : null,
                        fontFamilyFallback: _arabicScript(block)
                            ? const [
                                'Noto Naskh Arabic',
                                'Noto Sans Arabic',
                                'Traditional Arabic',
                                'Arial',
                                ...siteSansFallbacks,
                              ]
                            : siteSansFallbacks,
                      ),
                    ),
                  ),
            ] else if (text.isNotEmpty && verses) ...[
              for (final line in text.split(RegExp(r'\n+')))
                if (line.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      line.trim(),
                      textAlign: TextAlign.center,
                      style: siteText(
                        color: siteBlack,
                        fontSize: 18 * scale,
                        lineHeight: 26,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
            ] else if (text.isNotEmpty) ...[
              for (final paragraph in _paragraphs(text))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    paragraph,
                    textAlign: TextAlign.start,
                    style: siteText(
                      color: siteBlack,
                      fontSize: 18 * scale,
                      lineHeight: 26,
                    ),
                  ),
                ),
            ],
            for (final reference in references) ...[
              const SizedBox(height: 20),
              Text(
                reference,
                style: siteText(
                  color: siteBlack,
                  fontSize: 15 * scale,
                  lineHeight: 22,
                ),
              ),
            ],
          ],
        ),
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
