import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/site.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SitePage(
      children: [
        const SiteLogo(),
        const SiteGap(),
        const SiteBismillah(),
        const SiteGap(height: 44),
        const SiteBlackText(
          '"Perles Divines" est un receuil\n'
          'de prières et d\'invocations\n'
          'pour les musulmans Chiites (Ja\'ffari)',
        ),
        const SiteGap(height: 44),
        SiteButton(
          key: const Key('sommaire-button'),
          label: 'Sommaire',
          green: true,
          onTap: () => context.go('/sommaire'),
        ),
        const SiteGap(height: 44),
        const SiteBlackText(
          'Cette application est encore\n'
          'en cours d\'élaboration...\n'
          'Les textes et les audios embarqués\n'
          'sont disponibles hors connexion.',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Des mises à jour fréquentes\n'
          'apporteront de nouveaux contenus, InchAllah !',
        ),
        const SiteGap(),
        const SiteBlackText('Retrouvez ce site sur le web :', small: true),
        GestureDetector(
          onTap: () => openExternal(perlesSiteUrl),
          child: const SiteBlackText('www.perlesdivines.fr', small: true),
        ),
        GestureDetector(
          onTap: () => openMailto(perlesContactEmail),
          child: const SiteBlackText(perlesContactEmail, small: true),
        ),
      ],
    );
  }
}
