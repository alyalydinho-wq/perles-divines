import 'package:flutter/material.dart';

import '../duas/dua.dart';
import '../reader/content_install.dart';
import '../reader/reader_screen.dart';

class TextScreen extends StatefulWidget {
  const TextScreen({
    super.key,
    required this.item,
    required this.edition,
    required this.favorite,
    required this.onFavorite,
    this.textScale = 1.1,
  });

  final DevotionalText item;
  final LocalEdition edition;
  final bool favorite;
  final Future<void> Function() onFavorite;
  final double textScale;

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  late double scale = widget.textScale;
  late bool favorite = widget.favorite;
  int pane = 0;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final panes = <(String, Widget)>[
      ('Lecture', _reading(item.introduction, item.translation, item.references)),
      if (item.hasTransliteration)
        ('Translittération', _reading(null, item.transliteration, const [])),
      if (item.hasOriginalPage || item.hasArabic)
        (
          'Arabe',
          item.hasOriginalPage
              ? ReaderScreen(edition: widget.edition, initialPage: item.pagePath)
              : _reading(null, item.arabic, const [], rtl: true),
        ),
    ];
    final current = panes[pane.clamp(0, panes.length - 1)];
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Réduire le texte',
            onPressed: () => setState(() => scale = (scale - 0.1).clamp(0.9, 1.7)),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Agrandir le texte',
            onPressed: () => setState(() => scale = (scale + 0.1).clamp(0.9, 1.7)),
            icon: const Icon(Icons.text_increase),
          ),
          IconButton(
            tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: () async {
              await widget.onFavorite();
              if (mounted) setState(() => favorite = !favorite);
            },
            icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(kindLabel(item.kind)),
              ),
            ),
          ),
          if (panes.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final (i, pane) in panes.indexed)
                    ButtonSegment(value: i, label: Text(pane.$1)),
                ],
                selected: {pane.clamp(0, panes.length - 1)},
                onSelectionChanged: (value) => setState(() => pane = value.first),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: current.$2),
        ],
      ),
    );
  }

  Widget _reading(
    String? introduction,
    String body,
    List<String> references, {
    bool rtl = false,
  }) {
    final text = body.trim();
    final intro = introduction?.trim() ?? '';
    if (text.isEmpty && intro.isEmpty && references.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ce passage n’est pas en texte dans la page source. Ouvrez l’onglet Arabe pour la version originale.',
          ),
        ),
      );
    }
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (intro.isNotEmpty) ...[
            Text(
              intro,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.45,
                fontStyle: FontStyle.italic,
                fontSize: 16 * scale,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (text.isNotEmpty)
            Text(
              text,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.55,
                fontSize: 18 * scale,
              ),
            ),
          for (final reference in references) ...[
            const SizedBox(height: 20),
            Text(
              reference,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15 * scale,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
