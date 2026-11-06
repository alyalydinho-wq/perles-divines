import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Niveau de gras du texte arabe (police IndoPak, qui n’a qu’une seule graisse).
///
/// C’est l’épaisseur, en pixels logiques, ajoutée au trait des lettres, mesurée
/// pour une taille de [kArabicBoldnessRefSize]. Elle suit la taille de police
/// (A- / A+) et l’échelle de texte du système.
/// 0 = aucun gras ; ~0.4 = léger ; ~0.6 = marqué ; au-delà de ~1, les voyelles
/// risquent de se boucher.
const double kArabicBoldness = 0.6;

/// Taille de police pour laquelle [kArabicBoldness] s’applique tel quel.
const double kArabicBoldnessRefSize = 28;

/// Épaissit le trait de [style] sans toucher à la police, à la taille, à la
/// couleur ni à la hauteur de ligne : les glyphes sont redessinés quelques
/// fois, très légèrement décalés tout autour (même couleur, sans flou).
/// Les métriques de mise en page ne changent donc pas.
TextStyle arabicBoldStyle(TextStyle style, TextScaler scaler) {
  if (kArabicBoldness <= 0) return style;
  final size = style.fontSize ?? kArabicBoldnessRefSize;
  final reach = kArabicBoldness * scaler.scale(size) / kArabicBoldnessRefSize / 2;
  final color = style.color ?? const Color(0xFF000000);
  const directions = 8;
  return style.copyWith(
    shadows: [
      for (var i = 0; i < directions; i++)
        Shadow(
          color: color,
          blurRadius: 0,
          offset: Offset(
            reach * math.cos(2 * math.pi * i / directions),
            reach * math.sin(2 * math.pi * i / directions),
          ),
        ),
    ],
  );
}
