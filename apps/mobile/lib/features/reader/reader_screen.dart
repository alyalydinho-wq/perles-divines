import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'content_install.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.edition, this.initialPage});
  final LocalEdition edition;
  final String? initialPage;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final WebViewController controller;
  String? error;
  String current = '';
  List<String> anchors = [];
  @override
  void initState() {
    super.initState();
    controller = WebViewController();
    _initialize();
  }

  Future<void> _initialize() async {
    await controller.setJavaScriptMode(JavaScriptMode.disabled);
    if (controller.platform is AndroidWebViewController) {
      await (controller.platform as AndroidWebViewController)
          .setAllowContentAccess(false);
    }
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          if (uri.scheme == 'file') {
            final file = p.normalize(
              uri.replace(query: '', fragment: '').toFilePath(),
            );
            if (p.isWithin(widget.edition.directory, file)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
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
          final path = Uri.parse(url).path;
          final pages = (widget.edition.manifest['pages'] as List).where(
            (page) => path.endsWith(page['path']),
          );
          if (mounted) {
            setState(() {
              current = url;
              anchors = pages.isEmpty
                  ? []
                  : List<String>.from(pages.first['anchors'])
                        .where(
                          (a) => [
                            'TRADUCTION',
                            'TRANSLITTERATION',
                            'INFO',
                          ].contains(a),
                        )
                        .toList();
            });
          }
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
      Row(
        children: [
          IconButton(
            tooltip: 'Page précédente',
            onPressed: () async {
              if (await controller.canGoBack()) await controller.goBack();
            },
            icon: const Icon(Icons.arrow_back),
          ),
          TextButton(
            onPressed: () => _open(widget.edition.home),
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
      if (anchors.isNotEmpty)
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
