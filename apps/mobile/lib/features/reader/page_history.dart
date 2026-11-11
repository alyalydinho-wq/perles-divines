import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:path/path.dart' as p;

import '../../ui/motion.dart';

enum HistoryArrival { ignored, updated, reloadPrevious }

/// Pile des pages réellement affichées dans le WebView.
///
/// `about:blank` et un simple changement d’ancre (#TRADUCTION) ne comptent pas :
/// le retour doit revenir à la page précédente, pas à une page vide.
class LocalPageHistory {
  final List<String> _urls = [];
  bool restoring = false;

  List<String> get urls => List.unmodifiable(_urls);
  bool get canGoBack => _urls.length > 1;
  String? get current => _urls.isEmpty ? null : _urls.last;

  /// Page à réafficher pendant un retour, tant que la pile n’a pas été réduite.
  String? get previous => _urls.length < 2 ? null : _urls[_urls.length - 2];

  static bool isBlank(String url) {
    if (url.isEmpty || url == 'about:blank') return true;
    final uri = Uri.tryParse(url);
    return uri == null || uri.scheme == 'about';
  }

  /// Chemin local sans ancre, ou null si l’adresse n’est pas une page.
  static String? identity(String url) {
    if (isBlank(url)) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme == 'file') {
      try {
        final file = p.normalize(uri.toFilePath());
        return file.isEmpty ? null : file;
      } on UnsupportedError {
        return null;
      }
    }
    if (uri.path.isEmpty) return null;
    return '${uri.scheme}://${uri.host}${uri.path}';
  }

  static String? fileOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'file') return null;
    try {
      final file = p.normalize(uri.toFilePath());
      return file.isEmpty ? null : file;
    } on UnsupportedError {
      return null;
    }
  }

  /// Décide quoi faire d’une adresse qui vient de finir de charger.
  ///
  /// Une page vide pendant un retour demande de recharger [previous] :
  /// l’historique natif commence souvent par `about:blank`.
  HistoryArrival noteFinished(String url) {
    if (isBlank(url)) {
      if (restoring && previous != null) return HistoryArrival.reloadPrevious;
      if (restoring) cancelBack();
      return HistoryArrival.ignored;
    }
    return arrived(url) ? HistoryArrival.updated : HistoryArrival.ignored;
  }

  /// Enregistre la page qui vient de finir de charger.
  ///
  /// Pendant un retour, la pile est réduite jusqu’à cette page.
  bool arrived(String url) {
    final id = identity(url);
    if (id == null) return false;
    if (restoring) {
      restoring = false;
      final index = _urls.lastIndexWhere((entry) => identity(entry) == id);
      if (index >= 0) {
        if (index == _urls.length - 1) return false;
        _urls.removeRange(index + 1, _urls.length);
        return true;
      }
    } else if (_urls.isNotEmpty && identity(_urls.last) == id) {
      return false;
    }
    _urls.add(url);
    return true;
  }

  /// Prépare un retour d’une page. Null : il faut quitter l’écran Flutter.
  String? beginBack() {
    if (!canGoBack || restoring) return null;
    restoring = true;
    return previous;
  }

  void cancelBack() {
    restoring = false;
  }

  /// Oublie les pages déjà vues, par exemple avant de quitter pour le sommaire.
  void clear() {
    _urls.clear();
    restoring = false;
  }
}

/// Intercepte le retour (flèche, bouton système, geste) tant qu’une page
/// précédente est encore affichée dans le même écran.
class PageBackScope extends StatelessWidget {
  const PageBackScope({
    super.key,
    required this.hasPageHistory,
    required this.onPageBack,
    required this.child,
  });

  final bool hasPageHistory;
  final VoidCallback onPageBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasPageHistory,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onPageBack();
      },
      child: child,
    );
  }
}

/// Geste de bord iOS. Quand [enabled] est vrai, le geste système est coupé
/// par [PageBackScope] : ce détecteur appelle le même retour.
///
/// La page suit le doigt dès le bord. Au lâcher, l’élan décide : la page
/// part vers la droite à la vitesse du doigt et la précédente apparaît, ou
/// elle revient en place. On peut la rattraper pendant le mouvement.
class IosReadingBackEdge extends StatefulWidget {
  const IosReadingBackEdge({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<IosReadingBackEdge> createState() => _IosReadingBackEdgeState();
}

class _IosReadingBackEdgeState extends State<IosReadingBackEdge>
    with TickerProviderStateMixin {
  late final AnimationController _dx = AnimationController.unbounded(
    vsync: this,
  )..addListener(_redraw);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 200),
  )..addListener(_redraw);
  double _width = 1;

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dx.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) {
    _dx.stop();
    _fade.value = 1;
  }

  void _update(DragUpdateDetails details) {
    _dx.value = (_dx.value + details.delta.dx).clamp(0.0, _width);
  }

  void _end(double velocity) {
    final projected = _dx.value + projectMomentum(velocity);
    final reduced = reduceMotion(context);
    if (projected <= _width / 2) {
      if (reduced) {
        _dx.value = 0;
      } else {
        _dx.animateWith(
          SpringSimulation(uiSpring(response: 0.3), _dx.value, 0, velocity),
        );
      }
      return;
    }
    Navigator.of(context).maybePop();
    if (reduced) {
      _dx.value = 0;
      return;
    }
    _dx
        .animateWith(
          SpringSimulation(
            uiSpring(response: 0.3),
            _dx.value,
            _width,
            velocity.clamp(0.0, double.infinity),
          ),
        )
        .whenCompleteOrCancel(() {
          if (!mounted) return;
          // La page précédente prend la place en fondu : le WebView n’a
          // qu’une page à la fois, il n’y a rien à faire glisser dessous.
          _dx.value = 0;
          _fade
            ..value = 0
            ..forward();
        });
  }

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final active = widget.enabled && ios;
    return LayoutBuilder(
      builder: (context, box) {
        _width = box.maxWidth.isFinite && box.maxWidth > 0 ? box.maxWidth : 1;
        final dx = _dx.value.clamp(0.0, _width);
        final moving = dx > 0;
        // Le même arbre que la page soit déplacée ou non : le WebView
        // n’est jamais reconstruit par le geste.
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: moving
                    ? Color.lerp(
                        const Color(0x33000000),
                        const Color(0x00000000),
                        dx / _width,
                      )!
                    : const Color(0x00000000),
              ),
            ),
            Transform.translate(
              offset: Offset(dx, 0),
              child: FadeTransition(
                opacity: _fade,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: moving
                        ? const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 12,
                              offset: Offset(-2, 0),
                            ),
                          ]
                        : null,
                  ),
                  child: widget.child,
                ),
              ),
            ),
            if (active)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 28,
                child: GestureDetector(
                  key: const Key('reading-back-edge'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _start,
                  onHorizontalDragUpdate: _update,
                  onHorizontalDragEnd: (details) =>
                      _end(details.primaryVelocity ?? 0),
                  onHorizontalDragCancel: () => _end(0),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    );
  }
}
