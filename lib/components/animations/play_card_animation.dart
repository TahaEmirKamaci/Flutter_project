import 'package:flutter/material.dart';

class PlayCardAnimation extends StatefulWidget {
  final Widget child;
  final Offset startPosition;
  final Offset endPosition;
  final Duration duration;
  final VoidCallback? onComplete;

  const PlayCardAnimation({
    super.key,
    required this.child,
    required this.startPosition,
    required this.endPosition,
    this.duration = const Duration(milliseconds: 500),
    this.onComplete,
  });

  @override
  State<PlayCardAnimation> createState() => _PlayCardAnimationState();
}

class _PlayCardAnimationState extends State<PlayCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.endPosition,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 70),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// Helper widget for managing multiple card animations
class AnimatedCardStack extends StatefulWidget {
  final List<Widget> cards;
  final List<Offset> positions;
  final VoidCallback? onAnimationsComplete;

  const AnimatedCardStack({
    super.key,
    required this.cards,
    required this.positions,
    this.onAnimationsComplete,
  });

  @override
  State<AnimatedCardStack> createState() => _AnimatedCardStackState();
}

class _AnimatedCardStackState extends State<AnimatedCardStack> {
  int _completedAnimations = 0;

  void _onCardAnimationComplete() {
    setState(() {
      _completedAnimations++;
      if (_completedAnimations >= widget.cards.length && widget.onAnimationsComplete != null) {
        widget.onAnimationsComplete!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < widget.cards.length; i++)
          Positioned(
            left: widget.positions[i].dx,
            top: widget.positions[i].dy,
            child: widget.cards[i],
          ),
      ],
    );
  }
}
