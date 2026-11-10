import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Couleurs relevées dans `css/style.css` du site mobile.
const siteCanvas = Color(0xffffffff);
const siteGreen = Color(0xff145014);
const siteLink = Color(0xff124e12);
const siteBlack = Color(0xff000000);

/// Texte et icônes posés sur le vert. Le vert du site d’origine (#7db72f)
/// ne laissait que 2,4:1 de contraste au blanc ; ces teintes plus profondes
/// donnent au moins 4,8:1, le minimum conseillé pour du texte étant 4,5:1.
const siteButtonText = Color(0xffffffff);
const siteButtonBorder = Color(0xff606060);
const siteGreenSolid = Color(0xff467816);
const siteGreenTop = Color(0xff4b7f18);
const siteGreenBottom = Color(0xff38620e);
const siteWhiteButtonText = Color(0xff606060);
const siteWhiteButtonBorder = Color(0xff149214);
const siteWhiteTop = Color(0xffffffff);
const siteWhiteBottom = Color(0xffededed);

const siteSansFallbacks = <String>[
  'Lucida Sans Unicode',
  'Arial',
  'Verdana',
  'sans-serif',
];

const perlesSiteUrl = 'https://www.perlesdivines.fr';
const perlesContactEmail = 'contact@perlesdivines.fr';

/// Aligné sur `version:` de `apps/mobile/pubspec.yaml`.
const appVersion = '0.2.12';

const siteLogoAsset = 'assets/branding/logo-m.png';
const siteBismillahAsset = 'assets/branding/bismillah.gif';

TextStyle siteText({
  Color color = siteBlack,
  double fontSize = 18.67,
  double lineHeight = 22,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: 'Lucida Grande',
  fontFamilyFallback: siteSansFallbacks,
  color: color,
  fontSize: fontSize,
  height: lineHeight / fontSize,
  fontWeight: weight,
);

TextStyle get siteBodyBlack => siteText(color: siteBlack);
TextStyle get siteSmallBlack =>
    siteText(color: siteBlack, fontSize: 13.33, lineHeight: 16);

TextStyle get siteHeading => const TextStyle(
  fontFamily: 'Times New Roman',
  fontFamilyFallback: ['Times', 'serif'],
  color: siteBlack,
  fontSize: 37.33,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w700,
);

SystemUiOverlayStyle get siteOverlay => const SystemUiOverlayStyle(
  statusBarColor: siteCanvas,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: siteCanvas,
  systemNavigationBarIconBrightness: Brightness.dark,
);

Future<void> openExternal(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openMailto(String email) async {
  await launchUrl(Uri(scheme: 'mailto', path: email));
}

class SitePage extends StatelessWidget {
  const SitePage({super.key, required this.children, this.header, this.footer});

  final List<Widget> children;
  final List<Widget>? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: siteOverlay,
      child: Scaffold(
        backgroundColor: siteCanvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Le site d’origine est une colonne de téléphone.
                    // Sans ce plafond, un grand écran étire chaque résultat
                    // de recherche sur toute la fenêtre.
                    final frame = constraints.maxWidth < 480
                        ? constraints.maxWidth
                        : 480.0;
                    final bodyWidth = frame * 0.92;
                    Widget wrap(Widget child) => Center(
                      child: SizedBox(width: bodyWidth, child: child),
                    );
                    return Column(
                      children: [
                        if (header != null)
                          wrap(
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                children: [
                                  for (final child in header!)
                                    Center(child: child),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: wrap(
                            SingleChildScrollView(
                              padding: EdgeInsets.only(
                                top: header == null ? 22 : 12,
                                bottom: 28,
                              ),
                              child: Column(
                                children: [
                                  for (final child in children)
                                    Center(child: child),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class SiteLogo extends StatelessWidget {
  const SiteLogo({super.key, this.onTap, this.compact = false});
  final VoidCallback? onTap;

  /// Bandeau réduit des pages intérieures : le grand logo prenait près d’un
  /// cinquième de la hauteur de chaque écran.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * (compact ? 0.6 : 0.92);
        final radius = compact ? 8.0 : 12.0;
        // Même présentation que le site d’origine : image nette dans un
        // cadre blanc arrondi, avec l’ombre `.cadre`.
        final image = Container(
          width: width,
          margin: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
          decoration: BoxDecoration(
            color: siteCanvas,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0x80000000),
                blurRadius: compact ? 6 : 14,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              siteLogoAsset,
              width: width,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              errorBuilder: (context, error, stack) => SizedBox(
                width: width,
                height: width * 100 / 480,
                child: const ColoredBox(color: siteCanvas),
              ),
            ),
          ),
        );
        if (onTap == null) return image;
        return GestureDetector(onTap: onTap, child: image);
      },
    );
  }
}

class SiteBismillah extends StatelessWidget {
  const SiteBismillah({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      siteBismillahAsset,
      width: 290,
      fit: BoxFit.fitWidth,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) =>
          const SizedBox(width: 290, height: 52),
    );
  }
}

class SiteBlackText extends StatelessWidget {
  const SiteBlackText(this.text, {super.key, this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: small ? siteSmallBlack : siteBodyBlack,
  );
}

class SiteButton extends StatelessWidget {
  const SiteButton({
    super.key,
    required this.label,
    this.onTap,
    this.green = false,
    this.caption,
    this.icon,
    this.maxLines = 4,
  });

  final String label;
  final VoidCallback? onTap;
  final bool green;
  final String? caption;
  final IconData? icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final textColor = green ? siteButtonText : siteWhiteButtonText;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.92;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                width: width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: green ? siteButtonBorder : siteWhiteButtonBorder,
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: green
                        ? const [siteGreenTop, siteGreenBottom]
                        : const [siteWhiteTop, siteWhiteBottom],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14.72,
                    horizontal: 3.2,
                  ),
                  child: _SiteButtonLabel(
                    label: label,
                    caption: caption,
                    icon: icon,
                    maxLines: maxLines,
                    color: textColor,
                    green: green,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SiteButtonLabel extends StatelessWidget {
  const _SiteButtonLabel({
    required this.label,
    required this.color,
    required this.green,
    required this.maxLines,
    this.caption,
    this.icon,
  });

  final String label;
  final String? caption;
  final IconData? icon;
  final int maxLines;
  final Color color;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Lucida Grande',
      fontFamilyFallback: siteSansFallbacks,
      color: color,
      fontSize: 16,
      height: 1.15,
      fontWeight: FontWeight.w700,
      shadows: green
          ? const [
              Shadow(
                color: Color(0x4d000000),
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ]
          : null,
    );
    final title = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (icon == null && caption == null) return title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: siteGreenSolid),
              const SizedBox(width: 6),
            ],
            Flexible(child: title),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: siteText(
              color: siteGreen,
              fontSize: 12,
              lineHeight: 14,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class SiteSearchField extends StatelessWidget {
  const SiteSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Rechercher une prière ou une invocation',
    this.onHome,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.92;
        final field = TextField(
          key: const Key('site-search'),
          controller: controller,
          onChanged: onChanged,
          cursorColor: siteGreen,
          style: siteText(color: siteBlack, fontSize: 16, lineHeight: 20),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: siteText(
              color: siteWhiteButtonText,
              fontSize: 14,
              lineHeight: 18,
            ),
            prefixIcon: const Icon(Icons.search, color: siteGreenSolid),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: siteWhiteButtonBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: siteGreen, width: 1.4),
            ),
          ),
        );
        final home = onHome;
        if (home == null) {
          return SizedBox(width: width, child: field);
        }
        return SizedBox(
          width: width,
          child: Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              _SiteHomeButton(onTap: home),
            ],
          ),
        );
      },
    );
  }
}

class _SiteHomeButton extends StatelessWidget {
  const _SiteHomeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Retour au sommaire',
      child: Semantics(
        button: true,
        label: 'Retour au sommaire',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('section-home'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: siteWhiteButtonBorder),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [siteWhiteTop, siteWhiteBottom],
                ),
              ),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: Icon(Icons.home, color: siteGreenSolid, size: 26),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SiteGap extends StatelessWidget {
  const SiteGap({super.key, this.height = 22});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Hauteur des deux barres du bas du lecteur : réglage de police et langues.
const siteReaderBarHeight = 44.0;

/// Actions rangées dans le menu ⋮ de l’en-tête de lecture.
enum ReaderMenuAction { sommaire, top, download, share }

class SiteReaderHeader extends StatelessWidget {
  const SiteReaderHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onHome,
    this.onScrollToTop,
    this.onShare,
    this.onFavorite,
    this.onPlay,
    this.onDownload,
    this.onTextSize,
    this.favorite = false,
    this.playing = false,
    this.textSizeOpen = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onScrollToTop;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;

  /// Ouvre ou ferme le réglage de taille du texte.
  final VoidCallback? onTextSize;
  final bool favorite;

  /// L’audio de ce texte est en cours : le bouton devient Pause.
  final bool playing;
  final bool textSizeOpen;

  static const _barHeight = 56.0;
  static const _iconSlot = 48.0;
  static const _iconMin = 40.0;
  static const _titleMin = 120.0;

  bool get _hasMenu =>
      onHome != null ||
      onScrollToTop != null ||
      onDownload != null ||
      onShare != null;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Ink(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [siteGreenTop, siteGreenBottom],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = _slotFor(constraints.maxWidth);
                final trailing = <Widget>[
                  if (onTextSize != null)
                    _headerButton(
                      key: const Key('text-size-toggle'),
                      tooltip: textSizeOpen
                          ? 'Fermer la taille du texte'
                          : 'Taille du texte',
                      onPressed: onTextSize!,
                      slot: slot,
                      selected: textSizeOpen,
                      iconWidget: Text(
                        'Aa',
                        style: siteText(
                          color: siteButtonText,
                          fontSize: 19,
                          lineHeight: 22,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (onPlay != null)
                    _headerButton(
                      tooltip: playing ? 'Pause' : 'Lire',
                      icon: playing ? Icons.pause : Icons.play_arrow,
                      onPressed: onPlay!,
                      slot: slot,
                    ),
                  if (onFavorite != null)
                    _headerButton(
                      tooltip: favorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      icon: favorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      onPressed: onFavorite!,
                      slot: slot,
                    ),
                  if (_hasMenu) _menu(slot),
                ];
                return Row(
                  children: [
                    _headerButton(
                      tooltip: 'Retour',
                      icon: Icons.arrow_back,
                      onPressed: onBack,
                      slot: slot,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: siteText(
                            color: siteButtonText,
                            fontSize: 15,
                            lineHeight: 18,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    ...trailing,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _menu(double slot) {
    return SizedBox(
      width: slot,
      height: _iconSlot,
      child: PopupMenuButton<ReaderMenuAction>(
        key: const Key('reader-menu'),
        tooltip: 'Plus d’options',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert,
          color: siteButtonText,
          size: _glyphSize(slot),
        ),
        color: siteCanvas,
        onSelected: (action) {
          switch (action) {
            case ReaderMenuAction.sommaire:
              onHome?.call();
            case ReaderMenuAction.top:
              onScrollToTop?.call();
            case ReaderMenuAction.download:
              onDownload?.call();
            case ReaderMenuAction.share:
              onShare?.call();
          }
        },
        itemBuilder: (context) => [
          if (onHome != null)
            _menuItem(ReaderMenuAction.sommaire, Icons.home, 'Sommaire'),
          if (onScrollToTop != null)
            _menuItem(
              ReaderMenuAction.top,
              Icons.vertical_align_top,
              'Haut de la page',
            ),
          if (onDownload != null)
            _menuItem(
              ReaderMenuAction.download,
              Icons.download,
              'Télécharger l’audio',
            ),
          if (onShare != null)
            _menuItem(ReaderMenuAction.share, Icons.share, 'Partager'),
        ],
      ),
    );
  }

  PopupMenuItem<ReaderMenuAction> _menuItem(
    ReaderMenuAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, color: siteGreenSolid, size: 22),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, style: siteText(fontSize: 16, lineHeight: 20)),
        ),
      ],
    ),
  );

  double _slotFor(double width) {
    final count =
        1 +
        (onTextSize != null ? 1 : 0) +
        (onPlay != null ? 1 : 0) +
        (onFavorite != null ? 1 : 0) +
        (_hasMenu ? 1 : 0);
    if (count <= 0 || !width.isFinite || width <= 0) return _iconSlot;
    if (count * _iconSlot + _titleMin <= width) return _iconSlot;
    final fitted = (width - _titleMin) / count;
    if (fitted >= _iconMin) return fitted;
    if (count * _iconMin < width) return _iconMin;
    return width / count;
  }

  Widget _headerButton({
    required String tooltip,
    required VoidCallback onPressed,
    required double slot,
    Key? key,
    IconData? icon,
    Widget? iconWidget,
    bool selected = false,
  }) {
    final glyph =
        iconWidget ??
        Icon(icon!, size: _glyphSize(slot), color: siteButtonText);
    return Semantics(
      button: true,
      label: tooltip,
      child: ExcludeSemantics(
        child: SizedBox(
          width: slot,
          height: _iconSlot,
          child: IconButton(
            key: key,
            tooltip: tooltip,
            color: siteButtonText,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: slot,
              height: _iconSlot,
            ),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              fixedSize: Size(slot, _iconSlot),
              backgroundColor: selected
                  ? const Color(0x33ffffff)
                  : Colors.transparent,
            ),
            onPressed: onPressed,
            icon: glyph,
          ),
        ),
      ),
    );
  }

  double _glyphSize(double slot) =>
      slot >= _iconMin ? 24 : (24 * slot / _iconMin).clamp(20.0, 24.0);
}

class SiteTextTabs extends StatelessWidget {
  const SiteTextTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.labels = const ['Arabe', 'Traduction', 'Phonétique'],
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Material(
    color: siteCanvas,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: siteWhiteButtonBorder)),
      ),
      // L’inset bas appartient au lecteur du shell. Le réserver ici laissait
      // une bande blanche entre ces onglets et la barre audio.
      child: SizedBox(
        height: siteReaderBarHeight,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: i == selected
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [siteGreenTop, siteGreenBottom],
                            )
                          : null,
                      color: i == selected ? null : siteCanvas,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            style: siteText(
                              color: i == selected ? siteButtonText : siteBlack,
                              fontSize: labels.length > 3 ? 12 : 13,
                              lineHeight: 16,
                              weight: i == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
