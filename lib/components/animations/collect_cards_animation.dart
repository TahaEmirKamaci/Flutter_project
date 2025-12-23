import 'package:flutter/material.dart';

class CollectCardsAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const CollectCardsAnimation({super.key, required this.child, this.duration = const Duration(milliseconds: 400)});
  @override
  State<CollectCardsAnimation> createState() => _CollectCardsAnimationState();
}

class _CollectCardsAnimationState extends State<CollectCardsAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _t;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
    _c.forward();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: .92).animate(_t),
      child: FadeTransition(opacity: Tween(begin: 1.0, end: 0.0).animate(_t), child: widget.child),
    );
  }
}
