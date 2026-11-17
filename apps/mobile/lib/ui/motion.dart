import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Ressort décrit comme chez Apple : [damping] règle le rebond (1 = aucun),
/// [response] le temps, en secondes, pour rejoindre la cible.
SpringDescription uiSpring({double damping = 1.0, double response = 0.35}) {
  final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
  return SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: stiffness,
    ratio: damping,
  );
}

/// Distance que parcourrait un élan de [velocity] px/s en ralentissant comme
/// un défilement : on vise l’arrêt le plus proche de ce point, pas du doigt.
double projectMomentum(double velocity, [double decelerationRate = 0.998]) =>
    (velocity / 1000) * decelerationRate / (1 - decelerationRate);

/// Résistance progressive au-delà d’une limite : plus on tire, moins ça suit.
double rubberband(
  double overshoot,
  double dimension, [
  double constant = 0.55,
]) {
  if (dimension <= 0) return 0;
  return (overshoot * dimension * constant) /
      (dimension + constant * overshoot.abs());
}

/// Vrai quand le système demande de réduire les animations.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Tiroir du lecteur : il suit le doigt, puis un ressort repart de la
/// vitesse du geste vers l’état visé par l’élan. On peut le rattraper en
/// plein mouvement.
///
/// Au repos, seul l’état affiché est construit ; pendant le geste, les deux
/// faces se fondent l’une dans l’autre et la hauteur passe de l’une à
/// l’autre.
class PlaybackDrawer extends StatefulWidget {
  const PlaybackDrawer({
    super.key,
    required this.expanded,
    required this.onExpanded,
    required this.collapsed,
    required this.expandedFace,
  });

  final bool expanded;
  final ValueChanged<bool> onExpanded;
  final Widget collapsed;
  final Widget expandedFace;

  @override
  State<PlaybackDrawer> createState() => _PlaybackDrawerState();
}

class _PlaybackDrawerState extends State<PlaybackDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  /// Écart de hauteur entre les deux faces, mesuré à chaque mise en page.
  final _range = _Measured(72);
  double _target = 0;
  double _raw = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _target = widget.expanded ? 1 : 0;
    _t = AnimationController.unbounded(vsync: this, value: _target)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_dragging) {
          _t.value = _target;
        }
      });
  }

  @override
  void didUpdateWidget(PlaybackDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wanted = widget.expanded ? 1.0 : 0.0;
    if (!_dragging && wanted != _target) _settle(wanted, 0, momentum: false);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _settle(double target, double velocity, {required bool momentum}) {
    _target = target;
    if (reduceMotion(context)) {
      _t.value = target;
      return;
    }
    // Un rebond léger seulement quand le geste portait un élan.
    final spring = uiSpring(damping: momentum ? 0.8 : 1.0, response: 0.32);
    _t.animateWith(SpringSimulation(spring, _t.value, target, velocity));
  }

  void _start(DragStartDetails _) {
    _dragging = true;
    _t.stop();
    _raw = _t.value;
  }

  void _update(DragUpdateDetails details) {
    final range = _range.value;
    _raw += -details.delta.dy / range;
    // Au-delà des deux états, le tiroir résiste au lieu de s’arrêter net.
    final value = _raw > 1
        ? 1 + rubberband((_raw - 1) * range, range) / range
        : _raw < 0
        ? rubberband(_raw * range, range) / range
        : _raw;
    _t.value = value;
  }

  void _end(double velocityDy) {
    _dragging = false;
    final range = _range.value;
    final upward = -velocityDy;
    final projected = _t.value * range + projectMomentum(upward);
    final target = projected > range / 2 ? 1.0 : 0.0;
    _settle(target, upward / range, momentum: upward.abs() > 300);
    final expand = target == 1;
    if (expand != widget.expanded) {
      HapticFeedback.selectionClick();
      widget.onExpanded(expand);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t.value;
    final Widget child;
    if (t == 0) {
      child = widget.collapsed;
    } else if (t == 1) {
      child = widget.expandedFace;
    } else {
      child = _DrawerBlend(
        t: t,
        range: _range,
        collapsed: widget.collapsed,
        expanded: widget.expandedFace,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _start,
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: (details) => _end(details.primaryVelocity ?? 0),
      onVerticalDragCancel: () {
        if (_dragging) _end(0);
      },
      child: child,
    );
  }
}

class _Measured {
  _Measured(this.value);
  double value;
}

class _DrawerBlend extends MultiChildRenderObjectWidget {
  _DrawerBlend({
    required this.t,
    required this.range,
    required Widget collapsed,
    required Widget expanded,
  }) : super(children: [collapsed, expanded]);

  final double t;
  final _Measured range;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDrawerBlend(t, range);

  @override
  void updateRenderObject(BuildContext context, _RenderDrawerBlend render) {
    render
      ..t = t
      ..range = range;
  }
}

class _BlendData extends ContainerBoxParentData<RenderBox> {}

/// Deux faces alignées en bas : la hauteur suit [t] et la face réduite
/// s’efface au-dessus de la face dépliée.
class _RenderDrawerBlend extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BlendData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BlendData> {
  _RenderDrawerBlend(this._t, this.range);

  double _t;
  _Measured range;

  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  RenderBox get _collapsed => firstChild!;
  RenderBox get _expanded => childAfter(firstChild!)!;
  bool get _expandedWins => _t >= 0.5;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BlendData) child.parentData = _BlendData();
  }

  @override
  void performLayout() {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.minWidth;
    final inner = BoxConstraints.tightFor(width: width);
    _collapsed.layout(inner, parentUsesSize: true);
    _expanded.layout(inner, parentUsesSize: true);
    final low = _collapsed.size.height;
    final high = _expanded.size.height;
    if (high - low > 8) range.value = high - low;
    final height = math.max(0.0, low + (high - low) * _t);
    size = constraints.constrain(Size(width, height));
    (_collapsed.parentData! as _BlendData).offset = Offset(
      0,
      size.height - low,
    );
    (_expanded.parentData! as _BlendData).offset = Offset(
      0,
      size.height - high,
    );
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final shown = _t.clamp(0.0, 1.0);
    final collapsedAlpha = (1 - (shown - 0.15) / 0.6).clamp(0.0, 1.0);
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      context,
      offset,
    ) {
      void face(RenderBox child, double alpha) {
        if (alpha <= 0) return;
        final at = offset + (child.parentData! as _BlendData).offset;
        if (alpha >= 1) {
          context.paintChild(child, at);
          return;
        }
        context.pushOpacity(
          at,
          (alpha * 255).round(),
          (context, at) => context.paintChild(child, at),
        );
      }

      // La face dépliée apparaît au-dessus de la barre à mesure qu’elle
      // grandit, puis la barre réduite s’efface par-dessus.
      face(_expanded, 1);
      face(_collapsed, collapsedAlpha);
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _expandedWins ? _expanded : _collapsed;
    final data = child.parentData! as _BlendData;
    return result.addWithPaintOffset(
      offset: data.offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_expandedWins ? _expanded : _collapsed);
  }
}

/// Curseur de lecture qui reste sous le doigt : la position de l’audio ne
/// le reprend qu’une fois le doigt levé et la lecture arrivée à l’endroit
/// choisi.
class SeekSlider extends StatefulWidget {
  const SeekSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onSeek,
  });

  final double value;
  final double max;
  final ValueChanged<double>? onSeek;

  @override
  State<SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<SeekSlider> {
  double? _held;
  bool _dragging = false;
  Timer? _release;

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SeekSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final held = _held;
    // Lâché : on garde la valeur choisie jusqu’à ce que la lecture la
    // rejoigne, sinon le curseur reviendrait un instant en arrière.
    if (!_dragging && held != null && (widget.value - held).abs() < 1500) {
      _held = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seek = widget.onSeek;
    final shown = (_held ?? widget.value).clamp(0.0, widget.max).toDouble();
    return Slider(
      value: shown,
      max: widget.max,
      onChangeStart: seek == null
          ? null
          : (value) {
              _dragging = true;
              setState(() => _held = value);
            },
      onChanged: seek == null ? null : (value) => setState(() => _held = value),
      onChangeEnd: seek == null
          ? null
          : (value) {
              _dragging = false;
              setState(() => _held = value);
              seek(value);
              _release?.cancel();
              _release = Timer(const Duration(seconds: 2), () {
                if (mounted && !_dragging && _held == value) {
                  setState(() => _held = null);
                }
              });
            },
    );
  }
}

/// Déplacement minimal, en px, pour qu’un glissement entre lectures compte.
const swipeMinTravel = 48.0;

/// Sens d’un glissement horizontal entre lectures voisines : -1 vers la
/// gauche (lecture suivante), 1 vers la droite (précédente), 0 si le geste ne
/// change rien.
///
/// Pour compter, le geste doit avoir parcouru [swipeMinTravel], rester
/// nettement plus horizontal que vertical, et son élan doit le porter au-delà
/// de la moitié de la largeur : un doigt qui hésite ou revient en arrière
/// laisse la lecture en place.
int swipeDirection({
  required double dx,
  required double dyMax,
  required double velocity,
  required double width,
}) {
  if (dx.abs() < swipeMinTravel) return 0;
  if (dx.abs() < dyMax * 1.5) return 0;
  final projected = dx + projectMomentum(velocity);
  if (projected.sign != dx.sign) return 0;
  if (projected.abs() < width / 2) return 0;
  return dx.sign.toInt();
}

/// Vitesse horizontale du doigt au moment où il se lève, en px/s : le chemin
/// parcouru pendant les dernières [window], lever compris.
///
/// L’estimateur de Flutter ([VelocityTracker]) ignore le lever et rend zéro,
/// voire le mauvais sens, quand les points sont rares : un coup de doigt
/// court et franc passait alors pour un geste hésitant.
class FlickMeter {
  FlickMeter({this.window = const Duration(milliseconds: 100)});

  final Duration window;
  final List<(Duration, double)> _samples = [];

  void clear() => _samples.clear();

  void add(Duration time, double x) {
    _samples.add((time, x));
    if (_samples.length > 32) _samples.removeAt(0);
  }

  double get velocity {
    if (_samples.length < 2) return 0;
    final (end, endX) = _samples.last;
    var first = _samples.length - 1;
    while (first > 0 && end - _samples[first - 1].$1 <= window) {
      first--;
    }
    if (first == _samples.length - 1) {
      // Aucun point récent avant le lever. Si le doigt n’a pas bougé depuis
      // le dernier, il s’était arrêté et n’a plus d’élan. S’il a bougé, les
      // points ont seulement manqué (téléphone chargé) : le dernier trajet
      // donne la vitesse.
      final (previous, previousX) = _samples[_samples.length - 2];
      if ((endX - previousX).abs() < 2) return 0;
      final seconds = (end - previous).inMicroseconds / 1e6;
      return seconds > 0 ? (endX - previousX) / seconds : 0;
    }
    final (start, startX) = _samples[first];
    final seconds = (end - start).inMicroseconds / 1e6;
    if (seconds <= 0) return 0;
    return (endX - startX) / seconds;
  }
}

/// Place d’une lecture dans [PaneSwipe].
enum PaneRole {
  /// La lecture ouverte.
  current,

  /// La voisine que le doigt fait entrer, ou celle qui finit de sortir.
  beside,

  /// Une voisine prête, hors de l’écran.
  hidden,
}

/// Construit la lecture [index] pour la place [role].
typedef PaneBuilder = Widget Function(
  BuildContext context,
  int index,
  PaneRole role,
);

/// Glissement du doigt entre les lectures (Arabe, Traduction, Phonétique…),
/// comme on tourne une page : la lecture voisine entre avec le doigt, et la
/// bascule a lieu dès qu’on lâche, sans attendre qu’une page sorte avant que
/// l’autre arrive. Un geste hésitant laisse la lecture en place.
///
/// Les deux voisines sont construites hors de l’écran peu après l’ouverture :
/// le geste n’a rien à mettre en page quand il commence.
///
/// Le geste est lu sur les événements bruts du pointeur, sans arène : la zone
/// de sélection du texte s’empare des glissements horizontaux sur Android et
/// n’en fait rien, et la page d’origine (WebView) garde ses propres touches.
/// Un geste d’abord vertical est laissé au défilement.
class PaneSwipe extends StatefulWidget {
  const PaneSwipe({
    super.key,
    required this.index,
    required this.count,
    required this.onSwipe,
    required this.builder,
    this.ignoreLeftEdge = 0,
    this.warmDelay = const Duration(milliseconds: 450),
  });

  final int index;
  final int count;
  final ValueChanged<int> onSwipe;
  final PaneBuilder builder;

  /// Largeur, à gauche, laissée à un autre geste (retour iOS).
  final double ignoreLeftEdge;

  /// Attente avant de préparer les voisines : l’ouverture de la page et la
  /// fin d’un glissement passent d’abord.
  final Duration warmDelay;

  @override
  State<PaneSwipe> createState() => _PaneSwipeState();
}

class _PaneSwipeState extends State<PaneSwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dx = AnimationController.unbounded(
    vsync: this,
  )..addListener(_redraw);
  final Set<int> _ready = {};
  Timer? _warm;
  double _width = 1;
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _horizontal = false;
  double _grab = 0;
  double _base = 0;
  double _travel = 0;
  double _dyMax = 0;
  final _flick = FlickMeter();

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _scheduleWarm();
  }

  @override
  void didUpdateWidget(PaneSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ready.removeWhere((index) => index >= widget.count);
    if (oldWidget.index != widget.index || oldWidget.count != widget.count) {
      _scheduleWarm();
    }
  }

  @override
  void dispose() {
    _warm?.cancel();
    _dx.dispose();
    super.dispose();
  }

  bool _valid(int index) => index >= 0 && index < widget.count;

  void _scheduleWarm() {
    _warm?.cancel();
    _warm = Timer(widget.warmDelay, () {
      if (!mounted) return;
      final wanted = [
        widget.index - 1,
        widget.index + 1,
      ].where((index) => _valid(index) && !_ready.contains(index)).toList();
      if (wanted.isEmpty) return;
      setState(() => _ready.addAll(wanted));
    });
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || widget.count < 2) return;
    if (event.localPosition.dx < widget.ignoreLeftEdge) return;
    _pointer = event.pointer;
    _origin = event.position;
    _horizontal = false;
    _dyMax = 0;
    _travel = 0;
    _flick
      ..clear()
      ..add(event.timeStamp, event.position.dx);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final delta = event.position - _origin;
    _flick.add(event.timeStamp, event.position.dx);
    if (!_horizontal) {
      if (delta.distance < kTouchSlop) return;
      if (delta.dx.abs() <= delta.dy.abs()) {
        _release();
        return;
      }
      _horizontal = true;
      _dx.stop();
      _grab = delta.dx;
      _base = _dx.value;
    }
    _dyMax = math.max(_dyMax, delta.dy.abs());
    _travel = delta.dx - _grab;
    final offset = _base + _travel;
    final blocked =
        (offset < 0 && widget.index >= widget.count - 1) ||
        (offset > 0 && widget.index <= 0);
    _dx.value = blocked ? rubberband(offset, _width) : offset;
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _flick.add(event.timeStamp, event.position.dx);
    if (_horizontal) {
      // Le chemin fait jusqu’au lever compte, même sans mouvement reçu avant.
      final delta = event.position - _origin;
      _dyMax = math.max(_dyMax, delta.dy.abs());
      _travel = delta.dx - _grab;
    }
    _finish(_flick.velocity);
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _finish(0, cancelled: true);
  }

  void _release() {
    _pointer = null;
  }

  void _finish(double velocity, {bool cancelled = false}) {
    final horizontal = _horizontal;
    _horizontal = false;
    _release();
    if (!horizontal) return;
    var direction = cancelled
        ? 0
        : swipeDirection(
            dx: _travel,
            dyMax: _dyMax,
            velocity: velocity,
            width: _width,
          );
    final next = widget.index - direction;
    if (!_valid(next)) direction = 0;
    if (direction == 0) {
      _settle(velocity);
      return;
    }
    HapticFeedback.selectionClick();
    // La voisine devient la lecture ouverte là où le doigt l’a laissée :
    // elle finit d’entrer pendant que l’ancienne finit de sortir.
    _ready.add(widget.index);
    widget.onSwipe(next);
    _dx.value -= direction * _width;
    _settle(velocity);
  }

  void _settle(double velocity) {
    if (reduceMotion(context)) {
      _dx.value = 0;
      return;
    }
    _dx.animateWith(
      SpringSimulation(uiSpring(response: 0.28), _dx.value, 0, velocity),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _width = box.maxWidth.isFinite && box.maxWidth > 0 ? box.maxWidth : 1;
      final dx = _dx.value;
      final current = widget.index;
      // Sous un demi-pixel, le ressort est arrivé : la voisine se cache.
      final beside = dx < -0.5
          ? current + 1
          : dx > 0.5
          ? current - 1
          : null;
      final shown = beside != null && _valid(beside) ? beside : null;
      final indices = {..._ready, current, ?shown}.where(_valid).toList()
        ..sort();
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        child: ClipRect(
          child: Stack(
            children: [
              for (final index in indices)
                Positioned.fill(
                  // La même clé quand une voisine devient la lecture ouverte :
                  // elle n’est pas reconstruite et garde son défilement.
                  key: ValueKey(index),
                  child: _place(context, index, current, shown, dx),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _place(
    BuildContext context,
    int index,
    int current,
    int? shown,
    double dx,
  ) {
    final role = index == current
        ? PaneRole.current
        : index == shown
        ? PaneRole.beside
        : PaneRole.hidden;
    final hidden = role == PaneRole.hidden;
    final offset = switch (role) {
      PaneRole.current => dx,
      PaneRole.beside => dx + (index > current ? _width : -_width),
      PaneRole.hidden => 0.0,
    };
    // Toujours la même suite de widgets : passer de cachée à visible ne
    // reconstruit pas la lecture.
    return Offstage(
      offstage: hidden,
      child: TickerMode(
        enabled: !hidden,
        child: Transform.translate(
          offset: Offset(offset, 0),
          child: widget.builder(context, index, role),
        ),
      ),
    );
  }
}
