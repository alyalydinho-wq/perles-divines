import 'dart:async';
import 'dart:math' as math;

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
