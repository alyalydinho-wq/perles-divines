import 'dart:math' as math;

import 'package:flutter/material.dart';

const mahogany = Color(0xff3b2416);
const mahoganyDeep = Color(0xff2a1810);
const parchment = Color(0xfff3ead4);
const parchmentSoft = Color(0xffefe3c6);
const goldLeaf = Color(0xffd4b36a);
const goldPale = Color(0xffefe0b8);
const tealBloom = Color(0xff2f8a7c);
const leafGreen = Color(0xff2f7a3e);
const playGreen = Color(0xff2d9a58);
const inkBrown = Color(0xff2c1a12);
const searchGreen = Color(0xff3f8f4a);

String formatPlaybackClock(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final minutes = clamped.inMinutes;
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class FloralBannerPainter extends CustomPainter {
  const FloralBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = mahogany);
    final gold = Paint()
      ..color = goldLeaf.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final teal = Paint()..color = tealBloom.withValues(alpha: 0.9);
    final cream = Paint()..color = goldPale.withValues(alpha: 0.7);
    _vine(canvas, size, y: size.height * 0.22, paint: gold);
    _vine(canvas, size, y: size.height * 0.78, paint: gold);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.07 + i * 0.14);
      _bloom(canvas, Offset(x, size.height * 0.28), 7, teal);
      _bloom(canvas, Offset(x + 18, size.height * 0.72), 6, cream);
    }
  }

  void _vine(Canvas canvas, Size size, {required double y, required Paint paint}) {
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += 28) {
      path.quadraticBezierTo(x + 14, y + ((x ~/ 28).isEven ? -10 : 10), x + 28, y);
    }
    canvas.drawPath(path, paint);
  }

  void _bloom(Canvas canvas, Offset center, double radius, Paint paint) {
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.7,
        radius * 0.38,
        paint,
      );
    }
    canvas.drawCircle(center, radius * 0.28, Paint()..color = goldPale);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SideVinePainter extends CustomPainter {
  const SideVinePainter({required this.left});
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = goldLeaf.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final teal = Paint()..color = tealBloom.withValues(alpha: 0.45);
    final x = left ? size.width * 0.45 : size.width * 0.55;
    final path = Path()..moveTo(x, 0);
    for (var y = 0.0; y <= size.height; y += 36) {
      path.quadraticBezierTo(
        x + (left ? -10 : 10),
        y + 18,
        x,
        y + 36,
      );
    }
    canvas.drawPath(path, gold);
    for (var i = 0; i < 8; i++) {
      final center = Offset(x, 28.0 + i * 46);
      canvas.drawCircle(center, 4.5, teal);
    }
  }

  @override
  bool shouldRepaint(covariant SideVinePainter oldDelegate) =>
      oldDelegate.left != left;
}

class HeritageBanner extends StatelessWidget {
  const HeritageBanner({
    super.key,
    this.title = 'Perles Divines',
    this.height = 108,
  });

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: const FloralBannerPainter(),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: goldPale,
              letterSpacing: 0.4,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HeritageReaderHeader extends StatelessWidget {
  const HeritageReaderHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onShare,
    this.onFavorite,
    this.favorite = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final bool favorite;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: mahogany,
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 72,
        child: CustomPaint(
          painter: const FloralBannerPainter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                _roundButton(
                  icon: Icons.reply,
                  tooltip: 'Retour',
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: parchment,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: goldLeaf.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: inkBrown,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (onFavorite != null)
                  _roundButton(
                    icon: favorite ? Icons.favorite : Icons.favorite_border,
                    tooltip: favorite
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    onPressed: onFavorite!,
                  ),
                if (onShare != null) ...[
                  const SizedBox(width: 6),
                  _roundButton(
                    icon: Icons.share,
                    tooltip: 'Partager',
                    onPressed: onShare!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: playGreen,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    ),
  );
}

class HeritageSearchField extends StatelessWidget {
  const HeritageSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hint = 'Rechercher (ex. ashura)',
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: inkBrown, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: inkBrown.withValues(alpha: 0.45)),
        prefixIcon: const Icon(Icons.search, color: searchGreen),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: searchGreen, width: 1.6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: leafGreen, width: 2),
        ),
      ),
    ),
  );
}

class HeritageCategoryTile extends StatelessWidget {
  const HeritageCategoryTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: inkBrown,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: inkBrown.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class HeritageTextTabs extends StatelessWidget {
  const HeritageTextTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.labels = const ['Arabic', 'Translation', 'Transliteration'],
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: mahoganyDeep,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Material(
                  color: i == selected ? goldLeaf : parchmentSoft,
                  child: InkWell(
                    onTap: () => onSelected(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: inkBrown,
                          fontWeight: i == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14,
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
