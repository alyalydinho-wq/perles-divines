import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
class IosReadingBackEdge extends StatelessWidget {
  const IosReadingBackEdge({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    if (!enabled || !ios) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 28,
          child: GestureDetector(
            key: const Key('reading-back-edge'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) <= 200) return;
              Navigator.of(context).maybePop();
            },
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
