import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Marqueur de fin de verset tel qu’il est stocké : ﴿١٢٣﴾.
final quranAyahMarker = RegExp(r'\s*﴿\s*([0-9٠-٩۰-۹]+)\s*﴾\s*$');

/// Chiffres arabo-indiens (U+0660).
const arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Hauteur de ligne du mushaf. Au-dessus de 2 pour laisser un blanc
/// entre les descentes d’une ligne et les voyelles de la suivante,
/// là où passe le trait.
const quranLineHeight = 2.8;

/// Taille utilisée seulement si l’appelant n’en fournit pas.
const quranBaseFontSize = 32.0;

const quranFontFamily = 'AmiriQuran';

const _wordJoiner = '\u2060';

/// Le ۝ d’Amiri Quran ne place pas le chiffre dans l’ornement.
/// Le marqueur affiché est donc le ﴿١٢٣﴾ déjà présent dans les données.
const quranTextHeightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: true,
  applyHeightToLastDescent: true,
  leadingDistribution: TextLeadingDistribution.even,
);

/// Lecture mushaf : un seul flux arabe justifié, de droite à gauche.
///
/// Le texte religieux n’est pas réécrit. Le marqueur ﴿١٢٣﴾ reste dans le
/// flux, collé au dernier mot. Une ligne sans numéro placée avant le
/// premier verset (basmala des sourates autres qu’al-Fâtihah) reste une
/// en-tête, sans numéro ajouté.
class JustifiedQuranText extends StatelessWidget {
  const JustifiedQuranText({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final reading = quranReadingStyle(style);
    final parsed = _parse(text);
    if (parsed.headers.isEmpty && parsed.verses.isEmpty) {
      return const SizedBox.shrink();
    }
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < parsed.headers.length; i++)
            _RuledQuranText(
              span: TextSpan(style: reading, text: parsed.headers[i]),
              style: reading,
              textScaler: scaler,
              textKey: i == 0 ? const Key('quran-basmala') : null,
            ),
          if (parsed.verses.isNotEmpty)
            _RuledQuranText(
              span: TextSpan(
                style: reading,
                children: [
                  for (var i = 0; i < parsed.verses.length; i++)
                    TextSpan(text: _verseRun(parsed.verses[i], spaced: i > 0)),
                ],
              ),
              style: reading,
              textScaler: scaler,
              textKey: const Key('quran-flow'),
            ),
        ],
      ),
    );
  }
}

TextStyle quranReadingStyle(TextStyle base) {
  return TextStyle(
    inherit: false,
    fontFamily: quranFontFamily,
    fontFamilyFallback: const [
      'Indopak',
      'Noto Naskh Arabic',
      'Noto Sans Arabic',
      'Traditional Arabic',
    ],
    color: base.color ?? const Color(0xFF000000),
    fontSize: base.fontSize ?? quranBaseFontSize,
    height: quranLineHeight,
    fontWeight: FontWeight.w400,
  );
}

class _Verse {
  const _Verse(this.text, this.number);
  final String text;
  final int? number;
}

class _Parsed {
  const _Parsed(this.headers, this.verses);
  final List<String> headers;
  final List<_Verse> verses;
}

_Parsed _parse(String source) {
  final headers = <String>[];
  final verses = <_Verse>[];
  var started = false;
  for (final raw in source.split(RegExp(r'\n+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final match = quranAyahMarker.firstMatch(line);
    if (match == null) {
      if (!started) {
        headers.add(line);
      } else if (line.isNotEmpty) {
        verses.add(_Verse(line, null));
      }
      continue;
    }
    started = true;
    final body = line.substring(0, match.start).trim();
    final number = parseEasternDigits(match.group(1)!);
    if (body.isEmpty && number == null) continue;
    verses.add(_Verse(body, number));
  }
  return _Parsed(headers, verses);
}

String _verseRun(_Verse verse, {required bool spaced}) {
  final buffer = StringBuffer();
  if (spaced) buffer.write(' ');
  buffer.write(verse.text);
  final number = verse.number;
    if (number != null) {
    if (buffer.isNotEmpty) {
      // U+2060 colle le marqueur au dernier mot. U+00A0 empêche
      // un retour à la ligne juste devant l’ornement.
      buffer
        ..write(_wordJoiner)
        ..write('\u00A0');
    }
    buffer
      ..write('﴿')
      ..write(_indic(number))
      ..write('﴾');
  }
  return buffer.toString();
}

String _indic(int value) {
  return '$value'.replaceAllMapped(RegExp('[0-9]'), (match) {
    return arabicIndicDigits[int.parse(match[0]!)];
  });
}

int? parseEasternDigits(String value) {
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

class _RuledQuranText extends StatelessWidget {
  const _RuledQuranText({
    required this.span,
    required this.style,
    required this.textScaler,
    this.textKey,
  });

  final TextSpan span;
  final TextStyle style;
  final TextScaler textScaler;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    const locale = Locale('ar');
    return LayoutBuilder(
      builder: (context, constraints) {
        final stretched = _stretchShortLines(
          span: span,
          width: constraints.maxWidth,
          style: style,
          textScaler: textScaler,
          locale: locale,
          textHeightBehavior: quranTextHeightBehavior,
        );
        return SizedBox(
          width: double.infinity,
          child: CustomPaint(
            painter: QuranLineRulesPainter(
              span: stretched,
              textScaler: textScaler,
              locale: locale,
              textHeightBehavior: quranTextHeightBehavior,
              color: style.color ?? const Color(0xFF000000),
              fontSize: style.fontSize ?? quranBaseFontSize,
            ),
            child: Text.rich(
              stretched,
              key: textKey,
              style: style,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              textWidthBasis: TextWidthBasis.parent,
              textScaler: textScaler,
              locale: locale,
              textHeightBehavior: quranTextHeightBehavior,
            ),
          ),
        );
      },
    );
  }
}

/// Lettres qui se lient à la suivante : on peut y poser un tatwîl d’affichage.
const _joiningLetters = 'بتثجحخسشصضطظعغفقكلمنهيئ';

bool _joinsForward(int unit) => _joiningLetterSet.contains(unit);

final _joiningLetterSet = {for (final char in _joiningLetters.codeUnits) char};

bool _isMark(int unit) {
  return (unit >= 0x064B && unit <= 0x065F) ||
      unit == 0x0670 ||
      (unit >= 0x0610 && unit <= 0x061A) ||
      (unit >= 0x06D6 && unit <= 0x06ED) ||
      (unit >= 0x08D4 && unit <= 0x08FF);
}

bool _isLetter(int unit) {
  return (unit >= 0x0621 && unit <= 0x063A) ||
      (unit >= 0x0641 && unit <= 0x064A) ||
      unit == 0x0671;
}

TextPainter _painterFor(
  TextSpan span,
  double width,
  TextScaler textScaler,
  Locale locale,
  TextHeightBehavior? textHeightBehavior,
) {
  final painter = TextPainter(
    text: span,
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.justify,
    textWidthBasis: TextWidthBasis.parent,
    textScaler: textScaler,
    locale: locale,
    textHeightBehavior: textHeightBehavior,
  );
  painter.layout(maxWidth: width.isFinite ? width : 0);
  return painter;
}

double _tatweelWidth(
  TextStyle style,
  TextScaler textScaler,
  Locale locale,
  TextHeightBehavior? behavior,
) {
  double measure(String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
      locale: locale,
      textHeightBehavior: behavior,
    );
    painter.layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  final delta = measure('ب\u0640م') - measure('بم');
  final fallback = (style.fontSize ?? quranBaseFontSize) * 0.45;
  return delta >= 1 ? delta : fallback;
}

/// Allonge les lignes intermédiaires trop courtes avec U+0640.
///
/// Le moteur ne justifie une ligne que s’il y a un espace à étirer. Un mot
/// seul resterait collé à droite. Le tatwîl est un allongement d’affichage :
/// le texte stocké ne change pas, et la dernière ligne n’est pas étirée.
TextSpan _stretchShortLines({
  required TextSpan span,
  required double width,
  required TextStyle style,
  required TextScaler textScaler,
  required Locale locale,
  required TextHeightBehavior? textHeightBehavior,
}) {
  if (!width.isFinite || width <= 0) return span;
  final unit = _tatweelWidth(style, textScaler, locale, textHeightBehavior);
  var current = span;
  for (var pass = 0; pass < 2; pass++) {
    final painter = _painterFor(
      current,
      width,
      textScaler,
      locale,
      textHeightBehavior,
    );
    final metrics = painter.computeLineMetrics();
    final text = current.toPlainText();
    final inserts = <int, int>{};
    var offset = 0;
    for (var i = 0; i < metrics.length - 1; i++) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      if (range.end <= offset) break;
      final gap = math.max(
        metrics[i].left,
        width - (metrics[i].left + metrics[i].width),
      );
      if (gap >= 8) {
        final count = ((gap - 1) / unit).floor();
        _planTatweels(text, range.start, range.end, count, inserts);
      }
      offset = range.end;
    }
    painter.dispose();
    if (inserts.isEmpty) break;
    final next = _applyTatweels(current, inserts);
    final check = _painterFor(next, width, textScaler, locale, textHeightBehavior);
    final nextCount = check.computeLineMetrics().length;
    check.dispose();
    if (nextCount > metrics.length) break;
    current = next;
  }
  return current;
}

void _planTatweels(String text, int start, int end, int count, Map<int, int> inserts) {
  if (count <= 0 || start >= end) return;
  final points = <int>[];
  final stop = math.min(end, text.length);
  for (var i = start; i < stop; i++) {
    if (!_joinsForward(text.codeUnitAt(i))) continue;
    var next = i + 1;
    while (next < stop && _isMark(text.codeUnitAt(next))) {
      next++;
    }
    if (next >= stop) continue;
    final following = text.codeUnitAt(next);
    if (following == 0x06DD ||
        following == 0xFD3E ||
        following == 0xFD3F ||
        following == 0x0020 ||
        following == 0x00A0 ||
        following == 0x2060 ||
        following == 0x0640) {
      continue;
    }
    if (!_isLetter(following)) continue;
    points.add(next);
  }
  if (points.isEmpty) return;
  for (var n = 0; n < count; n++) {
    final at = points[n % points.length];
    inserts[at] = (inserts[at] ?? 0) + 1;
  }
}

TextSpan _applyTatweels(TextSpan span, Map<int, int> inserts) {
  var offset = span.text?.length ?? 0;
  final children = span.children;
  if (children == null || children.isEmpty) {
    return TextSpan(
      style: span.style,
      text: _insertTatweels(span.text ?? '', inserts, 0),
    );
  }
  final next = <InlineSpan>[];
  if (span.text != null && span.text!.isNotEmpty) {
    next.add(TextSpan(text: _insertTatweels(span.text!, inserts, 0)));
  }
  for (final child in children) {
    if (child is! TextSpan) {
      next.add(child);
      continue;
    }
    final text = child.text ?? '';
    next.add(TextSpan(style: child.style, text: _insertTatweels(text, inserts, offset)));
    offset += text.length;
  }
  return TextSpan(style: span.style, children: next);
}

String _insertTatweels(String text, Map<int, int> inserts, int base) {
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final extra = inserts[base + i] ?? 0;
    if (extra > 0) buffer.write('\u0640' * extra);
    buffer.write(text[i]);
  }
  return buffer.toString();
}

/// Traits de bord à bord sous chaque ligne, calés sur le même [TextPainter]
/// que le texte.
class QuranLineRulesPainter extends CustomPainter {
  QuranLineRulesPainter({
    required this.span,
    required this.textScaler,
    required this.locale,
    required this.textHeightBehavior,
    required this.color,
    required this.fontSize,
  });

  final TextSpan span;
  final TextScaler textScaler;
  final Locale? locale;
  final TextHeightBehavior? textHeightBehavior;
  final Color color;
  final double fontSize;

  TextPainter _layout(double width) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
      textWidthBasis: TextWidthBasis.parent,
      textScaler: textScaler,
      locale: locale,
      textHeightBehavior: textHeightBehavior,
    );
    painter.layout(maxWidth: math.max(0, width));
    return painter;
  }

  List<LineMetrics> lineMetrics(double width) {
    final painter = _layout(width);
    final metrics = painter.computeLineMetrics();
    painter.dispose();
    return metrics;
  }

  double laidOutHeight(double width) {
    final painter = _layout(width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double get _stroke => (fontSize / 46).clamp(0.6, 1.25);

  /// Un trait par ligne, sous la plus basse encre de cette ligne et
  /// au-dessus de l’encre de la ligne suivante.
  List<double> ruleYs(double width) {
    final painter = _layout(width);
    try {
      return _ruleYs(painter);
    } finally {
      painter.dispose();
    }
  }

  List<double> _ruleYs(TextPainter painter) {
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return const [];
    final text = span.toPlainText();
    final boxes = text.isEmpty
        ? const <TextBox>[]
        : painter.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.length),
          );
    final inkBottom = List<double>.filled(metrics.length, 0);
    final inkTop = List<double>.filled(metrics.length, double.infinity);
    for (var i = 0; i < metrics.length; i++) {
      inkBottom[i] = metrics[i].baseline;
      inkTop[i] = metrics[i].baseline;
    }
    for (final box in boxes) {
      final mid = (box.top + box.bottom) / 2;
      var line = 0;
      var best = double.infinity;
      for (var i = 0; i < metrics.length; i++) {
        final top = metrics[i].baseline - metrics[i].ascent;
        final bottom = metrics[i].baseline + metrics[i].descent;
        final center = (top + bottom) / 2;
        final distance = (mid - center).abs();
        if (distance < best) {
          best = distance;
          line = i;
        }
      }
      inkBottom[line] = math.max(inkBottom[line], box.bottom);
      inkTop[line] = math.min(inkTop[line], box.top);
    }
    final ys = <double>[];
    for (var i = 0; i < metrics.length; i++) {
      final nextTop = i + 1 < metrics.length ? inkTop[i + 1] : painter.height;
      final low = inkBottom[i];
      final high = nextTop - _stroke;
      final y = high > low ? low + (high - low) * 0.35 : (low + nextTop) / 2;
      ys.add(y);
    }
    return ys;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final painter = _layout(size.width);
    final paint = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    try {
      final ys = _ruleYs(painter);
      for (final y in ys) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } finally {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant QuranLineRulesPainter oldDelegate) {
    return oldDelegate.span.toPlainText() != span.toPlainText() ||
        oldDelegate.span.style != span.style ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.locale != locale ||
        oldDelegate.textHeightBehavior != textHeightBehavior ||
        oldDelegate.color != color ||
        oldDelegate.fontSize != fontSize;
  }
}
