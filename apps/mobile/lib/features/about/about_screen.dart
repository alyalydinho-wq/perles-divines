import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/site.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SitePage(
      children: [
        SiteLogo(onTap: () => context.go('/')),
        const SiteGap(),
        const SiteBlackText(
          '"Perles Divines" est un receuil\n'
          'de prières et d\'invocations\n'
          'pour les musulmans Chiites (Ja\'ffari)',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Ceci est une adaptation en français de l\'application\n'
          '"Divine Pearls"\n'
          'de Ejaz Hussain Z. AJANI\n'
          'Qu\'Allah (swt) le récompense pour son travail et sa générosité.',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Que cette humble contribution soit dédiée à l\'Imam de notre temps, Mohammad Mehdi (\'aj), en mémoire de nos defunts.',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Marhoum Hajee Firozhoussen\n'
          'GOULAMALY NASSOR\n'
          '(14 aout 1943 - 27 mars 2016)',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Marhoum Hajee Onaly\n'
          'ISSOUFALY DJIVAN\n'
          '(1er juin 1943 - 24 novembre 2016)',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Merci de réciter un souré Fatéha\n'
          'pour le Issalé Sawab de :',
        ),
        const SiteGap(height: 16),
        const SiteBlackText(
          'Marhoum Hajee Zahid Husain M. AJANI,\n\n'
          'Marhoum Hajee Firozhoussen GOULAMALY NASSOR,\n\n'
          'Marhouma Maléka FIROZHOUSSEN NASSOR,\n\n'
          'Marhoum Hajee Onaly ISSOUFALY DJIVAN,\n\n'
          'Nos grands-Parents,\n\n'
          'et tous les Marhoumines.',
        ),
        const SiteGap(),
        const SiteBlackText('Les ressources proviennent également de :'),
        const SiteBlackText(
          'www.sistani.org\n'
          'www.albouraq.org\n'
          'www.al-misbah.org\n'
          'www.bostani.com\n'
          'www.duas.org\n'
          'www.sibtayn.com\n'
          'www.tanzil.net\n'
          'www.thaqalayn.eu\n'
          'www.ziaraat.com',
        ),
        const SiteGap(height: 16),
        const SiteBlackText(
          'Que leurs auteurs\n'
          'soient aussi récompensés.',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Si vous constatez des fautes ou des erreurs, n\'hésitez pas à nous le faire savoir par mail.',
        ),
        const SiteGap(),
        const SiteBlackText(
          'Des mises à jour fréquentes\n'
          'apporteront de nouveaux contenus, InchAllah !',
        ),
        const SiteGap(),
        GestureDetector(
          onTap: () => openExternal(perlesSiteUrl),
          child: const SiteBlackText('www.perlesdivines.fr'),
        ),
        GestureDetector(
          onTap: () => openMailto(perlesContactEmail),
          child: const SiteBlackText(perlesContactEmail),
        ),
        const SiteGap(),
        const SiteBlackText(
          'Malécka & Mamode F. NASSOR\n'
          'Saint André - Réunion\n'
          '© Tous droits réservés.',
        ),
        const SiteGap(),
        SiteButton(
          label: 'Retour au sommaire',
          green: true,
          onTap: () => context.go('/sommaire'),
        ),
      ],
    );
  }
}
