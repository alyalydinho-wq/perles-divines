import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/about/about_screen.dart';
import 'features/catalog/audio_library_screen.dart';
import 'features/catalog/audio_shelves.dart';
import 'features/catalog/section_screen.dart';
import 'features/catalog/sections.dart';
import 'features/home/home_screen.dart';
import 'features/player/site_mini_player.dart';
import 'features/sommaire/sommaire_screen.dart';
import 'ui/site.dart';

GoRouter createRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ColoredBox(
        color: siteCanvas,
        child: Column(
          children: [
            Expanded(child: child),
            const SiteMiniPlayer(),
          ],
        ),
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/sommaire',
          builder: (context, state) => const SommaireScreen(),
        ),
        GoRoute(
          path: '/section/:id',
          builder: (context, state) {
            final section = CatalogSection.byId(state.pathParameters['id'] ?? '');
            if (section == null) {
              return SitePage(
                children: [
                  const SiteBlackText('Cette rubrique n’existe pas.'),
                  const SiteGap(),
                  SiteButton(
                    label: 'Retour au sommaire',
                    green: true,
                    onTap: () => context.go('/sommaire'),
                  ),
                ],
              );
            }
            return SectionScreen(section: section);
          },
        ),
        GoRoute(
          path: '/text/:id',
          builder: (context, state) =>
              CatalogTextPage(id: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/audios',
          builder: (context, state) => const AudioLibraryScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final shelf = AudioShelf.byId(state.pathParameters['id'] ?? '');
                if (shelf == null) {
                  return SitePage(
                    children: [
                      const SiteBlackText('Cette rubrique audio n’existe pas.'),
                      const SiteGap(),
                      SiteButton(
                        label: 'Retour aux audios',
                        green: true,
                        onTap: () => context.go('/audios'),
                      ),
                    ],
                  );
                }
                return AudioShelfScreen(shelf: shelf);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
  ],
);
