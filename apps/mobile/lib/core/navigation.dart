import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Change à chaque retour volontaire au sommaire.
///
/// « Sommaire » (menu, maison, logo, « Retour au sommaire ») ouvre un
/// sommaire vierge : la recherche faite avant est effacée. Le bouton retour,
/// lui, ne passe pas par ici et retrouve les résultats laissés.
final sommaireResets = ValueNotifier<int>(0);

void goToSommaire(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  sommaireResets.value++;
  GoRouter.maybeOf(context)?.go('/sommaire');
}
