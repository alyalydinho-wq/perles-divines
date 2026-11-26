import 'package:flutter/material.dart';

/// Niveau de gras du texte arabe (police IndoPak, qui n’a qu’une seule graisse).
///
/// C’est l’épaisseur, en pixels logiques, ajoutée au trait des lettres, mesurée
/// pour une taille de [kArabicBoldnessRefSize]. Elle suit la taille de police
/// (A- / A+) et l’échelle de texte du système.
/// 0 = aucun gras ; ~0.5 = léger ; ~0.75 = marqué ; au-delà de ~1.25, les
/// voyelles risquent de se boucher.
const double kArabicBoldness = 0.75;

/// Taille de police pour laquelle [kArabicBoldness] s’applique tel quel.
const double kArabicBoldnessRefSize = 28;

final _strokes = <(int, double), Paint>{};

/// Épaissit le trait de [style] sans toucher à la police, à la taille, à la
/// couleur ni à la hauteur de ligne : les lettres sont remplies puis
/// contournées d’un trait arrondi de [kArabicBoldness]. Les métriques de mise
/// en page ne changent donc pas.
///
/// Chaque mot n’est dessiné que deux fois (l’ancien gras, fait de huit ombres
/// décalées, le dessinait neuf fois).
///
/// Le même réglage rend toujours le même pinceau : deux styles identiques sont
/// alors égaux, et reconstruire l’écran ne redessine pas les mots déjà là.
TextStyle arabicBoldStyle(TextStyle style, TextScaler scaler) {
  if (kArabicBoldness <= 0) return style;
  final size = style.fontSize ?? kArabicBoldnessRefSize;
  final width = kArabicBoldness * scaler.scale(size) / kArabicBoldnessRefSize;
  final color = style.color ?? const Color(0xFF000000);
  return style.copyWith(
    // Le contour remplace la couleur pleine du texte…
    foreground: _strokes.putIfAbsent(
      (color.toARGB32(), width),
      () => Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    ),
    // … et l’ombre, toujours pleine, remplit les lettres. Une ombre sans
    // aucun décalage serait ignorée par le moteur : celui-ci, d’un millième de
    // pixel, ne se voit pas.
    shadows: [Shadow(color: color, offset: const Offset(0, 0.001))],
  );
}
