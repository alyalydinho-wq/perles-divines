import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation.dart';
import '../../ui/site.dart';

/// Pages d’origine du site, converties en blocs par `tools/native-pages.mjs`.
///
/// Elles s’affichent comme le reste de l’application, sans WebView : leurs
/// images sont lues directement dans l’application, rien n’est copié.
class OriginalPages {
  const OriginalPages(this.pages);
  final Map<String, OriginalPage> pages;

  static const asset = 'assets/content/pages.json';

  OriginalPage? operator [](String id) => pages[id.toLowerCase()];

  /// 450 Ko de JSON : lus hors de l’affichage, comme le catalogue.
  static Future<OriginalPages> load() async {
    final raw = await rootBundle.loadString(asset);
    return Isolate.run(() => parse(raw));
  }

  static OriginalPages parse(String raw) {
    final rows = jsonDecode(raw) as Map<String, dynamic>;
    return OriginalPages({
      for (final entry in rows.entries)
        entry.key.toLowerCase(): OriginalPage.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    });
  }
}

/// Efface la copie des pages HTML faite par les versions à WebView.
///
/// Un échec ne gêne rien : la suppression sera retentée au prochain lancement.
Future<void> removeCopiedEdition([Directory? support]) async {
  try {
    final root = support ?? await getApplicationSupportDirectory();
    final copy = Directory(p.join(root.path, 'content'));
    if (await copy.exists()) await copy.delete(recursive: true);
  } on Object {
    return;
  }
}

class OriginalPage {
  const OriginalPage({required this.title, required this.blocks});
  final String title;
  final List<PageBlock> blocks;

  factory OriginalPage.fromJson(Map<String, dynamic> json) => OriginalPage(
    title: json['title'] as String? ?? '',
    blocks: PageBlock.listFromJson(json['blocks'] as List<dynamic>? ?? []),
  );

  /// Index du bloc qui porte l’ancre [name], ou null.
  int? indexOf(String name) {
    for (var index = 0; index < blocks.length; index++) {
      if (blocks[index].holds(name)) return index;
    }
    return null;
  }
}

enum PageAlign { center, justify, left, right }

PageAlign _align(Object? value) => switch (value) {
  'j' => PageAlign.justify,
  'l' => PageAlign.left,
  'r' => PageAlign.right,
  _ => PageAlign.center,
};

sealed class PageBlock {
  const PageBlock(this.anchors);

  /// Repères `<a name>` de la page d’origine posés sur ce bloc.
  final List<String> anchors;

  /// Vrai si ce bloc, ou une cellule de sa rangée, porte l’ancre [name].
  bool holds(String name) => anchors.contains(name);

  static List<PageBlock> listFromJson(List<dynamic> rows) => [
    for (final row in rows) PageBlock.fromJson(row as Map<String, dynamic>),
  ];

  factory PageBlock.fromJson(Map<String, dynamic> json) {
    final anchors = List<String>.from(json['k'] as List? ?? const []);
    if (json['p'] case final List<dynamic> spans) {
      return ParagraphBlock(
        anchors: anchors,
        spans: [
          for (final span in spans)
            PageSpan.fromJson(span as Map<String, dynamic>),
        ],
        align: _align(json['a']),
        rtl: json['d'] == 'rtl',
        arabic: json['ar'] == 1,
      );
    }
    if (json['img'] case final String name) {
      return ImageBlock(
        anchors: anchors,
        name: name,
        intrinsicWidth: (json['iw'] as num).toDouble(),
        intrinsicHeight: (json['ih'] as num).toDouble(),
        width: (json['w'] as num?)?.toDouble(),
        fraction: (json['f'] as num?)?.toDouble(),
        align: _align(json['a']),
        link: json['h'] as String?,
      );
    }
    if (json['button'] case final String label) {
      return ButtonBlock(
        anchors: anchors,
        label: label,
        green: json['green'] == 1,
        link: json['h'] as String,
      );
    }
    if (json['row'] case final List<dynamic> cells) {
      return RowBlock(
        anchors: anchors,
        cells: [
          for (final cell in cells) PageBlock.listFromJson(cell as List),
        ],
      );
    }
    if (json.containsKey('hr')) return RuleBlock(anchors);
    return GapBlock(anchors, (json['gap'] as num?)?.toInt() ?? 0);
  }
}

class PageSpan {
  const PageSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.points,
    this.link,
  });
  final String text;
  final bool bold, italic, underline;
  final Color? color;

  /// Taille en points du site ; null vaut 14 pt, la taille du texte courant.
  final double? points;
  final String? link;

  factory PageSpan.fromJson(Map<String, dynamic> json) {
    final hex = json['c'] as String?;
    return PageSpan(
      text: json['t'] as String,
      bold: json['b'] == 1,
      italic: json['i'] == 1,
      underline: json['u'] == 1,
      color: hex == null
          ? null
          : Color(0xff000000 | int.parse(hex.substring(1), radix: 16)),
      points: (json['s'] as num?)?.toDouble(),
      link: json['h'] as String?,
    );
  }
}

class ParagraphBlock extends PageBlock {
  const ParagraphBlock({
    required List<String> anchors,
    required this.spans,
    this.align = PageAlign.center,
    this.rtl = false,
    this.arabic = false,
  }) : super(anchors);
  final List<PageSpan> spans;
  final PageAlign align;
  final bool rtl, arabic;

  String get text => spans.map((span) => span.text).join();
}

class ImageBlock extends PageBlock {
  const ImageBlock({
    required List<String> anchors,
    required this.name,
    required this.intrinsicWidth,
    required this.intrinsicHeight,
    this.width,
    this.fraction,
    this.align = PageAlign.center,
    this.link,
  }) : super(anchors);
  final String name;
  final double intrinsicWidth, intrinsicHeight;

  /// Largeur voulue par la page, en pixels ou en part de la colonne.
  final double? width, fraction;
  final PageAlign align;
  final String? link;

  String get asset => 'assets/pages/$name';
}

class ButtonBlock extends PageBlock {
  const ButtonBlock({
    required List<String> anchors,
    required this.label,
    required this.link,
    this.green = false,
  }) : super(anchors);
  final String label, link;
  final bool green;
}

class RowBlock extends PageBlock {
  const RowBlock({required List<String> anchors, required this.cells})
    : super(anchors);
  final List<List<PageBlock>> cells;

  @override
  bool holds(String name) =>
      super.holds(name) ||
      cells.any((cell) => cell.any((block) => block.holds(name)));
}

class RuleBlock extends PageBlock {
  const RuleBlock(super.anchors);
}

class GapBlock extends PageBlock {
  const GapBlock(super.anchors, this.halfLines);
  final int halfLines;
}

/// Où mène un lien d’une page d’origine.
sealed class PageDestination {
  const PageDestination();
}

class OpenSommaire extends PageDestination {
  const OpenSommaire();
}

class ScrollToAnchor extends PageDestination {
  const ScrollToAnchor(this.anchor);
  final String anchor;
}

/// Un texte du catalogue ou une autre page d’origine.
class OpenCatalogPage extends PageDestination {
  const OpenCatalogPage(this.id, this.anchor);
  final String id;
  final String? anchor;
}

class OpenExternal extends PageDestination {
  const OpenExternal(this.uri);
  final Uri uri;
}

PageDestination? pageDestination(String link) {
  if (link == 'sommaire') return const OpenSommaire();
  if (link.startsWith('#') && link.length > 1) {
    return ScrollToAnchor(link.substring(1));
  }
  if (link.startsWith('page:')) {
    final rest = link.substring(5);
    final cut = rest.indexOf('#');
    final id = cut < 0 ? rest : rest.substring(0, cut);
    final anchor = cut < 0 ? null : rest.substring(cut + 1);
    if (id.isEmpty) return null;
    return OpenCatalogPage(id, anchor == null || anchor.isEmpty ? null : anchor);
  }
  final uri = Uri.tryParse(link);
  if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
    return OpenExternal(uri);
  }
  return null;
}

/// Adresse de l’application pour un lien vers [id].
///
/// [opensText] dit si [id] est un texte du catalogue qui s’ouvre en lecture
/// (lecture native mise à jour, ou texte dont la page est l’onglet Arabe) ;
/// sinon une page d’origine connue s’ouvre seule.
String? pageLocation(
  String id,
  String? anchor, {
  required bool Function(String id) opensText,
  required bool Function(String id) hasPage,
  required bool Function(String id) inCatalog,
}) {
  final query = anchor == null
      ? ''
      : '?anchor=${Uri.encodeQueryComponent(anchor)}';
  if (opensText(id)) return '/text/$id$query';
  if (hasPage(id)) return '/page/$id$query';
  if (inCatalog(id)) return '/text/$id';
  return null;
}

/// Ouvre une adresse externe après confirmation : l’application reste hors
/// connexion tant qu’on ne la quitte pas.
Future<void> confirmExternal(BuildContext context, Uri uri) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ressource externe'),
      content: Text(
        '${uri.scheme == 'mailto' ? 'Ouvrir votre application courriel' : 'Une connexion Internet est nécessaire pour cette destination'} :\n$uri',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ouvrir'),
        ),
      ],
    ),
  );
  if (open != true) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Impossible d’ouvrir cette destination.')),
    );
  }
}

/// Une page d’origine, affichée en natif.
///
/// [scale] suit le réglage « Aa » : 1 pour la taille « Normal ». Les images
/// gardent leur taille, comme sur le site.
class OriginalPageView extends StatefulWidget {
  const OriginalPageView({
    super.key,
    required this.page,
    this.controller,
    this.scale = 1,
    this.initialAnchor,
    this.onLink,
    this.arabicStyle,
    this.contextMenuBuilder,
  });

  final OriginalPage page;
  final ScrollController? controller;
  final double scale;
  final String? initialAnchor;

  /// Liens vers une autre page, le sommaire ou une adresse externe.
  /// Les ancres de la page sont suivies ici.
  final ValueChanged<PageDestination>? onLink;
  final TextStyle? arabicStyle;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  @override
  State<OriginalPageView> createState() => OriginalPageViewState();
}

class OriginalPageViewState extends State<OriginalPageView> {
  ScrollController? _own;
  final Map<int, GlobalKey> _keys = {};

  ScrollController get _scroll =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void initState() {
    super.initState();
    final anchor = widget.initialAnchor;
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal(anchor));
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  GlobalKey _keyOf(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  /// Fait défiler jusqu’au bloc qui porte [anchor].
  ///
  /// La liste ne construit que ce qui est à l’écran : on saute d’abord à une
  /// position estimée, puis on cale le bloc une fois construit.
  Future<void> reveal(String anchor) async {
    final index = widget.page.indexOf(anchor);
    if (index == null) return;
    for (var attempt = 0; attempt < 6; attempt++) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _keys[index]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target, alignment: 0);
        return;
      }
      final position = _scroll.position;
      final count = widget.page.blocks.length;
      final estimate = count <= 1
          ? 0.0
          : position.maxScrollExtent * index / (count - 1);
      position.jumpTo(estimate.clamp(0.0, position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _follow(String link) {
    final destination = pageDestination(link);
    if (destination == null) return;
    if (destination is ScrollToAnchor) {
      unawaited(reveal(destination.anchor));
      return;
    }
    widget.onLink?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.page.blocks;
    final list = ListView.builder(
      controller: _scroll,
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        final child = _PageBlockView(
          block: block,
          scale: widget.scale,
          arabicStyle: widget.arabicStyle,
          onLink: _follow,
        );
        // Seuls les blocs qui portent une ancre ont besoin d’une clé.
        return _hasAnchor(block)
            ? KeyedSubtree(key: _keyOf(index), child: child)
            : child;
      },
    );
    return ColoredBox(
      color: context.site.canvas,
      child: SelectionArea(
        contextMenuBuilder: widget.contextMenuBuilder,
        child: list,
      ),
    );
  }

  static bool _hasAnchor(PageBlock block) =>
      block.anchors.isNotEmpty ||
      (block is RowBlock &&
          block.cells.any((cell) => cell.any(_hasAnchor)));
}

class _PageBlockView extends StatelessWidget {
  const _PageBlockView({
    required this.block,
    required this.scale,
    required this.onLink,
    this.arabicStyle,
  });
  final PageBlock block;
  final double scale;
  final TextStyle? arabicStyle;
  final ValueChanged<String> onLink;

  /// 14 pt, le texte courant du site, valent 18,67 px à la taille « Normal ».
  double get _base => 14 * 4 / 3 * scale;

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    switch (block) {
      case ParagraphBlock():
        return Padding(
          padding: EdgeInsets.only(bottom: _base * 0.6),
          child: _Paragraph(
            block: block,
            scale: scale,
            arabicStyle: arabicStyle,
            onLink: onLink,
          ),
        );
      case ImageBlock():
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PageImage(block: block, onLink: onLink),
        );
      case ButtonBlock():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SiteButton(
            label: block.label,
            green: block.green,
            onTap: () => onLink(block.link),
          ),
        );
      case RowBlock():
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final cell in block.cells)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final inner in cell)
                      _PageBlockView(
                        block: inner,
                        scale: scale,
                        arabicStyle: arabicStyle,
                        onLink: onLink,
                      ),
                  ],
                ),
              ),
          ],
        );
      case RuleBlock():
        return Divider(height: _base, color: context.site.panelBorder);
      case GapBlock():
        return SizedBox(height: block.halfLines * _base * 0.6);
    }
  }
}

TextAlign _textAlign(PageAlign align) => switch (align) {
  PageAlign.center => TextAlign.center,
  PageAlign.justify => TextAlign.justify,
  PageAlign.left => TextAlign.left,
  PageAlign.right => TextAlign.right,
};

class _Paragraph extends StatefulWidget {
  const _Paragraph({
    required this.block,
    required this.scale,
    required this.onLink,
    this.arabicStyle,
  });
  final ParagraphBlock block;
  final double scale;
  final TextStyle? arabicStyle;
  final ValueChanged<String> onLink;

  @override
  State<_Paragraph> createState() => _ParagraphState();
}

class _ParagraphState extends State<_Paragraph> {
  /// Un geste par lien, créé avec le paragraphe : `onLink` est relu au
  /// toucher, il peut changer sans recréer les gestes.
  List<TapGestureRecognizer?> _taps = const [];

  @override
  void initState() {
    super.initState();
    _taps = _recognizers();
  }

  @override
  void didUpdateWidget(_Paragraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block != widget.block) {
      _release();
      _taps = _recognizers();
    }
  }

  List<TapGestureRecognizer?> _recognizers() => [
    for (final span in widget.block.spans)
      if (span.link case final link?)
        TapGestureRecognizer()..onTap = () => widget.onLink(link)
      else
        null,
  ];

  void _release() {
    for (final tap in _taps) {
      tap?.dispose();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final ink = context.site.ink;
    final base = siteText(
      color: ink,
      fontSize: 14 * 4 / 3 * widget.scale,
      lineHeight: 14 * 4 / 3 * widget.scale * 1.4,
    );
    final arabic = block.arabic
        ? (widget.arabicStyle ??
              const TextStyle(fontFamily: 'Indopak', height: 2.06))
        : null;
    return Text.rich(
      TextSpan(
        style: arabic ?? base,
        children: [
          for (final (index, span) in block.spans.indexed)
            TextSpan(
              text: span.text,
              recognizer: _taps[index],
              style: TextStyle(
                color: span.color,
                fontSize: arabic != null || span.points == null
                    ? null
                    : span.points! * 4 / 3 * widget.scale,
                fontWeight: span.bold ? FontWeight.w700 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
                decoration: span.underline ? TextDecoration.underline : null,
                decorationColor: span.color,
              ),
            ),
        ],
      ),
      textAlign: _textAlign(block.align),
      textDirection: block.rtl || block.arabic ? TextDirection.rtl : null,
    );
  }
}

class _PageImage extends StatelessWidget {
  const _PageImage({required this.block, required this.onLink});
  final ImageBlock block;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final max = box.maxWidth.isFinite ? box.maxWidth : block.intrinsicWidth;
      final wanted = block.fraction != null
          ? max * block.fraction!
          : block.width ?? block.intrinsicWidth;
      final width = wanted.clamp(1.0, max).toDouble();
      final height = width * block.intrinsicHeight / block.intrinsicWidth;
      final pixels = (width * MediaQuery.devicePixelRatioOf(context)).round();
      Widget image = Image.asset(
        block.asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        // Décodée à la taille affichée quand elle est plus petite : une
        // grande calligraphie ne garde pas en mémoire des pixels inutiles.
        cacheWidth: pixels < block.intrinsicWidth ? pixels : null,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: block.link == null,
        errorBuilder: (context, error, stack) =>
            SizedBox(width: width, height: height),
      );
      final link = block.link;
      if (link != null) {
        image = Semantics(
          button: true,
          child: InkWell(onTap: () => onLink(link), child: image),
        );
      }
      return Align(
        alignment: switch (block.align) {
          PageAlign.left || PageAlign.justify => Alignment.centerLeft,
          PageAlign.right => Alignment.centerRight,
          PageAlign.center => Alignment.center,
        },
        child: image,
      );
    },
  );
}

/// Suit un lien d’une page d’origine depuis n’importe quel écran.
void followPageDestination(
  BuildContext context,
  PageDestination destination, {
  required String? Function(String id, String? anchor) locate,
}) {
  switch (destination) {
    case OpenSommaire():
      goToSommaire(context);
    case ScrollToAnchor():
      return;
    case OpenCatalogPage(:final id, :final anchor):
      final location = locate(id, anchor);
      if (location != null) GoRouter.maybeOf(context)?.push(location);
    case OpenExternal(:final uri):
      unawaited(confirmExternal(context, uri));
  }
}
