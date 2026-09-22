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
const appVersion = '0.1.0';

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
TextStyle get siteSmallGreen =>
    siteText(fontSize: 13.33, lineHeight: 16);
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
  const SitePage({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

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
                    final bodyWidth = constraints.maxWidth * 0.92;
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
        final image = ColoredBox(
          color: siteCanvas,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              siteLogoAsset,
              width: width,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.medium,
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
      errorBuilder: (context, error, stack) => const SizedBox(
        width: 290,
        height: 52,
      ),
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
    required this.onTap,
    this.green = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool green;

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
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lucida Grande',
                      fontFamilyFallback: siteSansFallbacks,
                      color: textColor,
                      fontSize: 16,
                      height: 1,
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
                    ),
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

class SiteSearchField extends StatelessWidget {
  const SiteSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Rechercher une prière ou une invocation',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.92;
        return SizedBox(
          width: width,
          child: TextField(
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
          ),
        );
      },
    );
  }
}

class SiteGap extends StatelessWidget {
  const SiteGap({super.key, this.height = 22});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class SiteReaderHeader extends StatelessWidget {
  const SiteReaderHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onShare,
    this.onFavorite,
    this.onPlay,
    this.favorite = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onPlay;
  final bool favorite;

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
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Retour',
                  color: siteButtonText,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
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
                if (onPlay != null)
                  IconButton(
                    tooltip: 'Lire',
                    color: siteButtonText,
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow),
                  ),
                if (onFavorite != null)
                  IconButton(
                    tooltip: favorite
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    color: siteButtonText,
                    onPressed: onFavorite,
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                if (onShare != null)
                  IconButton(
                    tooltip: 'Partager',
                    color: siteButtonText,
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
      child: SizedBox(
        height: 44,
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
                      child: Text(
                        labels[i],
                        style: siteText(
                          color: i == selected ? siteButtonText : siteBlack,
                          fontSize: 13,
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
          ],
        ),
      ),
    ),
  );
}
