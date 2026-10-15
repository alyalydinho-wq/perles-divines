import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Couleurs relevées dans `css/style.css` du site mobile.
const siteCanvas = Color(0xffffffff);
const siteGreen = Color(0xff145014);
const siteLink = Color(0xff124e12);
const siteBlack = Color(0xff000000);
const siteButtonText = Color(0xffe8f0de);
const siteButtonBorder = Color(0xff606060);
const siteGreenSolid = Color(0xff64991e);
const siteGreenTop = Color(0xff7db72f);
const siteGreenBottom = Color(0xff4e7d0e);
const siteWhiteButtonText = Color(0xff606060);
const siteWhiteButtonBorder = Color(0xff149214);
const siteWhiteTop = Color(0xffffffff);
const siteWhiteBottom = Color(0xffededed);
const siteGlow = Color(0xffffffd0);

const siteSansFallbacks = <String>[
  'Lucida Sans Unicode',
  'Arial',
  'Verdana',
  'sans-serif',
];

const perlesSiteUrl = 'https://www.perlesdivines.fr';
const perlesContactEmail = 'contact@perlesdivines.fr';

/// Aligné sur `version:` de `apps/mobile/pubspec.yaml`.
const appVersion = '0.2.7';

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

TextStyle get siteBodyGreen => siteText();
TextStyle get siteBodyBlack => siteText(color: siteBlack);
TextStyle get siteSmallGreen => siteText(fontSize: 13.33, lineHeight: 16);
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
  const SiteLogo({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.92;
        // Même présentation que le site d’origine : image nette dans un
        // cadre blanc arrondi, avec l’ombre `.cadre`.
        final image = Container(
          width: width,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: siteCanvas,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 14),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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

class SiteGreenText extends StatelessWidget {
  const SiteGreenText(this.text, {super.key, this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: small ? siteSmallGreen : siteBodyGreen,
  );
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
    this.favorite = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onScrollToTop;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final bool favorite;

  static const _barHeight = 56.0;
  static const _iconSlot = 48.0;
  static const _iconMin = 40.0;
  static const _titleMin = 150.0;

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
                final leading = <Widget>[
                  _headerButton(
                    tooltip: 'Retour',
                    icon: Icons.arrow_back,
                    onPressed: onBack,
                    slot: _slotFor(constraints.maxWidth),
                  ),
                  if (onHome != null)
                    _headerButton(
                      tooltip: 'Sommaire',
                      icon: Icons.home,
                      onPressed: onHome!,
                      slot: _slotFor(constraints.maxWidth),
                    ),
                ];
                final trailing = <Widget>[
                  if (onScrollToTop != null)
                    _headerButton(
                      tooltip: 'Haut de la page',
                      icon: Icons.keyboard_arrow_up,
                      onPressed: onScrollToTop!,
                      slot: _slotFor(constraints.maxWidth),
                    ),
                  if (onPlay != null)
                    _headerButton(
                      tooltip: 'Lire',
                      icon: Icons.play_arrow,
                      onPressed: onPlay!,
                      slot: _slotFor(constraints.maxWidth),
                    ),
                  if (onDownload != null)
                    _headerButton(
                      tooltip: 'Télécharger',
                      icon: Icons.download,
                      onPressed: onDownload!,
                      slot: _slotFor(constraints.maxWidth),
                    ),
                  if (onFavorite != null)
                    _headerButton(
                      tooltip: favorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      onPressed: onFavorite!,
                      slot: _slotFor(constraints.maxWidth),
                      iconWidget: ExcludeSemantics(
                        child: _FavoriteHeart(selected: favorite),
                      ),
                    ),
                  if (onShare != null)
                    _headerButton(
                      tooltip: 'Partager',
                      icon: Icons.share,
                      onPressed: onShare!,
                      slot: _slotFor(constraints.maxWidth),
                    ),
                ];
                return Row(
                  children: [
                    ...leading,
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          maxLines: 1,
                          softWrap: false,
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

  double _slotFor(double width) {
    final count =
        1 +
        (onHome != null ? 1 : 0) +
        (onScrollToTop != null ? 1 : 0) +
        (onPlay != null ? 1 : 0) +
        (onDownload != null ? 1 : 0) +
        (onFavorite != null ? 1 : 0) +
        (onShare != null ? 1 : 0);
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
    IconData? icon,
    Widget? iconWidget,
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
            tooltip: tooltip,
            color: iconWidget == null ? siteButtonText : null,
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

/// Cœur blanc quand le texte est en favori. Sinon, cœur vert cerclé de blanc.
class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return const Icon(Icons.favorite, color: Color(0xffffffff));
    }
    return const SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.favorite, color: Color(0xffffffff), size: 24),
          Icon(Icons.favorite, color: siteGreen, size: 18),
        ],
      ),
    );
  }
}

class SiteTextTabs extends StatelessWidget {
  const SiteTextTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.labels = const ['Arabic', 'Translation', 'Transliteration'],
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
