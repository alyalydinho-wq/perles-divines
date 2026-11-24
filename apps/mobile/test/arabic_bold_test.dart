import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perles_divines/ui/arabic_bold.dart';

const _ink = Color(0xFF000000);
const _base = TextStyle(
  fontFamily: 'Indopak',
  color: _ink,
  fontSize: 28,
  height: 2.06,
);

void main() {
  test('le gras arabe ne dessine chaque mot que deux fois', () {
    final style = arabicBoldStyle(_base, TextScaler.noScaling);
    // Le texte lui-même (contour) et une seule ombre (remplissage) : l’ancien
    // gras à huit ombres faisait saccader le défilement de l’arabe.
    expect(style.shadows, hasLength(1));
    expect(style.foreground!.style, PaintingStyle.stroke);
    expect(style.foreground!.strokeWidth, closeTo(kArabicBoldness, 1e-9));
    expect(style.color, isNull);
    // Une ombre sans décalage est ignorée par le moteur : les lettres
    // resteraient creuses.
    expect(style.shadows!.single.offset, isNot(Offset.zero));
    expect(style.shadows!.single.color, _ink);
  });

  test('le gras arabe suit l’échelle de texte du système', () {
    final style = arabicBoldStyle(_base, const TextScaler.linear(1.5));
    expect(style.foreground!.strokeWidth, closeTo(kArabicBoldness * 1.5, 1e-9));
  });

  testWidgets('le gras arabe remplit les lettres et les épaissit', (
    tester,
  ) async {
    final bytes = File('assets/fonts/indopak.ttf').readAsBytesSync();
    await (FontLoader(
      'Indopak',
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();

    Future<double> ink(TextStyle style) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Text('بِرَحْمَتِكَ الَّتِي وَسِعَتْ', style: style),
              ),
            ),
          ),
        ),
      );
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.75);
        final raw = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var dark = 0.0;
        for (var i = 0; i < raw.lengthInBytes; i += 4) {
          dark += (255 - raw.getUint8(i)) / 255;
        }
        image.dispose();
        return dark;
      }))!;
    }

    final regular = await ink(_base);
    final bold = await ink(arabicBoldStyle(_base, TextScaler.noScaling));
    // Lettres creuses (contour seul) : moins d’encre que le texte normal.
    expect(bold, greaterThan(regular * 1.25));
    expect(bold, lessThan(regular * 1.75));
  });
}
