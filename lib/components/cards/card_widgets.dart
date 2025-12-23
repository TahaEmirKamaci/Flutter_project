import 'package:flutter/material.dart';
import 'dart:math';

class CardWidget extends StatelessWidget {
  final String label; // e.g. A♥
  final bool raised;
  final bool selectable;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final double scale;
  const CardWidget({
    super.key,
    required this.label,
    this.raised = false,
    this.selectable = false,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final suitChar = label.characters.last;
    final rank = label.substring(0, label.length - 1);
    final isRed = suitChar == '♥' || suitChar == '♦';
    final color = isRed ? const Color(0xFFD84315) : const Color(0xFF212121);
    final elevation = selected ? 16.0 : 6.0;
    final yOffset = raised || selected ? -15.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translate(0.0, yOffset)
        ..scale(selected ? scale * 1.05 : scale),
      child: GestureDetector(
        onTap: selectable ? onTap : null,
        onDoubleTap: selectable ? onDoubleTap : null,
        child: Container(
          width: 64 * scale,
          height: 92 * scale,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFBDA468) : Colors.grey.shade300,
              width: selected ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: elevation,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 6,
                left: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    // Removed small suit under rank per request (side small symbol)
                  ],
                ),
              ),
              Center(
                child: Text(
                  suitChar,
                  style: TextStyle(
                    fontSize: 34,
                    color: color.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardBackWidget extends StatelessWidget {
  final double scale;
  final bool blue;
  const CardBackWidget({super.key, this.scale = 1.0, this.blue = true});
  @override
  Widget build(BuildContext context) {
    final grad = blue
        ? const LinearGradient(colors: [Color(0xFF2E5DA8), Color(0xFF1B3E70)])
        : const LinearGradient(colors: [Color(0xFF5F6266), Color(0xFF3E4043)]);
    return Container(
      width: 64 * scale,
      height: 92 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: grad,
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(painter: _BackPatternPainter()),
    );
  }
}

class _BackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.white.withOpacity(0.25);
    for (double x = 8; x < size.width - 8; x += 6) {
      for (double y = 8; y < size.height - 8; y += 6) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A simple stacked deck representation.
class CardStack extends StatelessWidget {
  final int count;
  final Axis axis;
  final bool blueBack;
  const CardStack({
    super.key,
    required this.count,
    this.axis = Axis.vertical,
    this.blueBack = true,
  });
  @override
  Widget build(BuildContext context) {
    final visible = count.clamp(0, 14);
    final children = List.generate(visible, (i) {
      final offset = i * (axis == Axis.vertical ? 6.0 : 10.0);
      return Positioned(
        top: axis == Axis.vertical ? offset : 0,
        left: axis == Axis.horizontal ? offset : 0,
        child: CardBackWidget(blue: blueBack, scale: .9),
      );
    });
    return SizedBox(
      width: axis == Axis.horizontal ? 64 + (visible - 1) * 10 : 70,
      height: axis == Axis.vertical ? 92 + (visible - 1) * 6 : 100,
      child: Stack(children: children),
    );
  }
}

/// 3D flip wrapper (stub) for future enhancement.
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool flipped;
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.flipped,
  });
  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final angle = _c.value * pi;
        final isFront = angle <= pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isFront
              ? widget.front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: widget.back,
                ),
        );
      },
    );
  }
}
