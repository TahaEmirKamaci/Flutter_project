import 'package:flutter/material.dart';

class DealAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const DealAnimation({super.key, required this.child, this.duration = const Duration(milliseconds: 150)});
  @override
  State<DealAnimation> createState() => _DealAnimationState();
}

class _DealAnimationState extends State<DealAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _t;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(_t), child: widget.child),
    );
  }
}
