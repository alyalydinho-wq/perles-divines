import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'content_install.dart';
import 'page_history.dart';

final _catalogPage = RegExp(
  r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.html$',
  caseSensitive: false,
);

/// Ancien sommaire (`sommaire.html`) et ancienne page d’accueil (`index.html`).
const legacySommairePageNames = {
  '1af50233-0b26-5c4b-993e-c96c078fdb46.html',
  '386bba3e-88c0-5136-bd4e-8215613a7064.html',
};

const _legacySitePaths = {
  '/',
  '/index.html',
  '/sommaire.html',
  '/fr',
  '/fr/index.html',
  '/fr/sommaire.html',
};

/// Vrai pour le sommaire ou l’accueil de l’ancien site, en local ou en ligne.
///
/// L’ancre et les paramètres ne comptent pas. Le nom du bouton non plus.
bool isLegacySommaireUrl(Uri uri) {
  if (uri.scheme == 'mailto') return false;
  final name = _pageFileName(uri);
  if (name != null && legacySommairePageNames.contains(name)) return true;
  final localFile = uri.scheme == 'file' || uri.scheme.isEmpty;
  if (localFile && (name == 'index.html' || name == 'sommaire.html')) {
    return true;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host != 'perlesdivines.fr' && host != 'www.perlesdivines.fr') {
    return false;
  }
  if (name == 'index.html' || name == 'sommaire.html') return true;
  final path = uri.path.isEmpty ? '/' : uri.path;
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return _legacySitePaths.contains(normalized.toLowerCase());
}

String? _pageFileName(Uri uri) {
  final raw = uri.scheme == 'file' ? _filePath(uri) : uri.path;
  if (raw == null || raw.isEmpty || raw == '/') return null;
  final name = p.basename(raw).toLowerCase();
  return name.isEmpty ? null : name;
}

String? _filePath(Uri uri) {
  try {
    return p.normalize(uri.replace(query: '', fragment: '').toFilePath());
  } on UnsupportedError {
    return uri.path;
  }
}

/// Où mène un lien du WebView, avant tout chargement.
enum ReaderNavigation {
  showPage,
  openUpdatedText,
  openAppSommaire,
  external,
  blocked,
}

ReaderNavigation decideReaderNavigation(
  Uri uri, {
  required String editionDirectory,
  bool Function(String id)? opensUpdatedText,
}) {
  if (isLegacySommaireUrl(uri)) return ReaderNavigation.openAppSommaire;
  if (uri.scheme == 'file') {
    final file = _filePath(uri);
    if (file == null || !p.isWithin(editionDirectory, file)) {
      return ReaderNavigation.blocked;
    }
    final id = localCatalogId(uri, editionDirectory);
    if (id != null && (opensUpdatedText?.call(id) ?? false)) {
      return ReaderNavigation.openUpdatedText;
    }
    return ReaderNavigation.showPage;
  }
  if (uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'mailto') {
    return ReaderNavigation.external;
  }
  return ReaderNavigation.blocked;
}

/// Identifiant catalogue d’une page locale, si l’adresse reste dans l’édition.
String? localCatalogId(Uri uri, String editionDirectory) {
  if (uri.scheme != 'file') return null;
  final String file;
  try {
    file = p.normalize(uri.replace(query: '', fragment: '').toFilePath());
  } on UnsupportedError {
    return null;
  }
  if (!p.isWithin(editionDirectory, file)) return null;
  return _catalogPage.firstMatch(p.basename(file))?.group(1)?.toLowerCase();
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.edition,
    this.initialPage,
    this.compact = false,
    this.opensUpdatedText,
    this.onOpenUpdatedText,
    this.onOpenAppSommaire,
    this.onPageHistory,
  });
  final LocalEdition edition;
  final String? initialPage;
  final bool compact;

  /// Vrai quand cette page a une lecture native mise à jour.
  final bool Function(String id)? opensUpdatedText;

  /// Ouvre cette lecture à la place de l’ancienne page HTML.
  final void Function(String id)? onOpenUpdatedText;

  /// Remplace l’ancien sommaire HTML par le sommaire de l’application.
  final VoidCallback? onOpenAppSommaire;

  /// Vrai tant qu’une page précédente peut être réaffichée ici.
  final ValueChanged<bool>? onPageHistory;

  @override
  State<ReaderScreen> createState() => ReaderScreenState();
}

class ReaderScreenState extends State<ReaderScreen> {
  late final WebViewController controller;
  final history = LocalPageHistory();
  final Map<String, Offset> _offsets = {};
  String? error;
  String current = '';
  List<String> anchors = [];
  bool _ready = false;
  bool _publishedHistory = false;
  int _blankHops = 0;
  String? _restoreId;

  @override
  void initState() {
    super.initState();
    controller = WebViewController();
    _initialize();
  }

  Future<void> _initialize() async {
    await controller.setJavaScriptMode(JavaScriptMode.disabled);
    // Pincement natif. enableZoom(true) ne réactive pas JavaScript.
    await controller.enableZoom(true);
    if (controller.platform is AndroidWebViewController) {
      await (controller.platform as AndroidWebViewController)
          .setAllowContentAccess(false);
    }
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          final decision = decideReaderNavigation(
            uri,
            editionDirectory: widget.edition.directory,
            opensUpdatedText: widget.opensUpdatedText,
          );
          switch (decision) {
            case ReaderNavigation.openAppSommaire:
              _leaveForAppSommaire();
              return NavigationDecision.prevent;
            case ReaderNavigation.openUpdatedText:
              final id = localCatalogId(uri, widget.edition.directory);
              final open = widget.onOpenUpdatedText;
              if (id != null && open != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) open(id);
                });
              }
              return NavigationDecision.prevent;
            case ReaderNavigation.showPage:
              await _rememberScroll();
              return NavigationDecision.navigate;
            case ReaderNavigation.blocked:
              return NavigationDecision.prevent;
            case ReaderNavigation.external:
              break;
          }
          if (['https', 'http', 'mailto'].contains(uri.scheme)) {
            if (!mounted) return NavigationDecision.prevent;
            final open = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Ressource externe'),
                content: Text(
                  '${uri.scheme == 'mailto' ? 'Ouvrir votre application courriel' : 'Une connexion Internet est nécessaire pour cette destination'} :\n${uri.toString()}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Ouvrir'),
                  ),
                ],
              ),
            );
            if (open == true) {
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!ok && mounted) {
                setState(
                  () => error = 'Impossible d’ouvrir cette destination.',
                );
              }
            }
          }
          return NavigationDecision.prevent;
        },
        onPageFinished: (url) {
          unawaited(_finished(url));
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame == true && mounted) {
            setState(
              () => error = 'Cette page locale ne peut pas être ouverte.',
            );
          }
        },
      ),
    );
    await _open(_startFile());
    _ready = true;
  }

  Future<void> _finished(String url) async {
    if (!mounted) return;
    final arrival = history.noteFinished(url);
    if (arrival == HistoryArrival.reloadPrevious) {
      final target = history.previous;
      if (target != null && _blankHops < 2) {
        _blankHops++;
        await _reload(target);
        return;
      }
      history.cancelBack();
      _blankHops = 0;
      _publishHistory();
      return;
    }
    _blankHops = 0;
    final restoreId = _restoreId;
    _restoreId = null;
    _publishHistory();
    final path = Uri.parse(url).path;
    final pages = (widget.edition.manifest['pages'] as List).where(
      (page) => path.endsWith(page['path']),
    );
    if (!mounted) return;
    setState(() {
      current = url;
      anchors = pages.isEmpty
          ? []
          : List<String>.from(pages.first['anchors'])
                .where(
                  (a) => ['TRADUCTION', 'TRANSLITTERATION', 'INFO'].contains(a),
                )
                .toList();
    });
    if (restoreId != null && LocalPageHistory.identity(url) == restoreId) {
      final offset = _offsets[restoreId];
      if (offset != null && offset.dy > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(controller.scrollTo(offset.dx.round(), offset.dy.round()));
        });
      }
    }
  }

  void _leaveForAppSommaire() {
    history.clear();
    _blankHops = 0;
    _restoreId = null;
    _publishHistory();
    final open = widget.onOpenAppSommaire;
    if (open == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) open();
    });
  }

  void _publishHistory() {
    final can = history.canGoBack;
    if (can == _publishedHistory) return;
    _publishedHistory = can;
    widget.onPageHistory?.call(can);
  }

  Future<void> _rememberScroll() async {
    final id = history.current == null
        ? null
        : LocalPageHistory.identity(history.current!);
    if (id == null) return;
    try {
      _offsets[id] = await controller.getScrollPosition();
    } catch (_) {}
  }

  /// Revient à la page précédente du WebView.
  ///
  /// `goBack` conserve le défilement. S’il n’y a pas d’historique natif,
  /// la page précédente est rechargée et le défilement mémorisé est reposé.
  /// Retourne faux seulement quand l’écran Flutter doit se fermer.
  Future<bool> goBack() async {
    if (!_ready || history.restoring) return history.canGoBack;
    final target = history.beginBack();
    if (target == null) return false;
    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
        return true;
      }
      await _reload(target);
      return true;
    } catch (_) {
      history.cancelBack();
      _publishHistory();
      return false;
    }
  }

  Future<void> _reload(String url) async {
    final file = LocalPageHistory.fileOf(url);
    if (file == null) {
      history.cancelBack();
      _publishHistory();
      return;
    }
    _restoreId = LocalPageHistory.identity(url);
    await _open(file);
  }

  String _startFile() {
    final relative = widget.initialPage;
    if (relative == null || relative.isEmpty) return widget.edition.home;
    if (p.isAbsolute(relative) || relative.split('/').contains('..')) {
      return widget.edition.home;
    }
    final file = p.normalize(p.join(widget.edition.directory, relative));
    return p.isWithin(widget.edition.directory, file)
        ? file
        : widget.edition.home;
  }

  Future<void> scrollToTop() => controller.scrollTo(0, 0);

  Future<void> _open(String file) async {
    if (Platform.isIOS) {
      await controller.platform.loadFileWithParams(
        WebKitLoadFileParams(
          absoluteFilePath: file,
          readAccessPath: widget.edition.directory,
        ),
      );
    } else {
      await controller.loadFile(file);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!widget.compact)
        Row(
          children: [
            IconButton(
              tooltip: 'Page précédente',
              onPressed: () {
                unawaited(goBack());
              },
              icon: const Icon(Icons.arrow_back),
            ),
            TextButton(
              onPressed: _leaveForAppSommaire,
              child: const Text('Sommaire'),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Haut de page',
              onPressed: () => controller.scrollTo(0, 0),
              icon: const Icon(Icons.vertical_align_top),
            ),
          ],
        ),
      if (!widget.compact && anchors.isNotEmpty)
        Wrap(
          children: anchors
              .map(
                (a) => TextButton(
                  onPressed: () => controller.loadRequest(
                    Uri.parse(current).replace(fragment: a),
                  ),
                  child: Text(
                    {
                      'TRADUCTION': 'Traduction',
                      'TRANSLITTERATION': 'Translittération',
                      'INFO': 'Informations',
                    }[a]!,
                  ),
                ),
              )
              .toList(),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      Expanded(child: WebViewWidget(controller: controller)),
    ],
  );
}
