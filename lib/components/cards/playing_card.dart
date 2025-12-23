import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlayingCard extends StatefulWidget {
  final String cardId;
  final bool isFaceUp;
  final bool isSelected;
  final bool isRaised;
  final double scale;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool animateEntry;
  
  const PlayingCard({
    Key? key,
    required this.cardId,
    this.isFaceUp = false,
    this.isSelected = false,
    this.isRaised = false,
    this.scale = 1.0,
    this.onTap,
    this.onDoubleTap,
    this.animateEntry = false,
  }) : super(key: key);

  @override
  State<PlayingCard> createState() => _PlayingCardState();
}

class _PlayingCardState extends State<PlayingCard> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showFront = false;

  @override
  void initState() {
    super.initState();
    _showFront = widget.isFaceUp;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    
    if (widget.animateEntry) {
      Future.delayed(Duration.zero, () => _flipController.forward());
    }
  }

  @override
  void didUpdateWidget(PlayingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFaceUp != widget.isFaceUp) {
      if (widget.isFaceUp) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
      _showFront = widget.isFaceUp;
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = 64.0 * widget.scale;
    final height = 92.0 * widget.scale;
    final elevation = widget.isSelected ? 12.0 : 4.0;
    final yOffset = widget.isRaised || widget.isSelected ? -12.0 * widget.scale : 0.0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translate(0.0, yOffset)
        ..scale(widget.isSelected ? 1.08 : 1.0),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * math.pi;
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle);
            
            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: angle < math.pi / 2
                  ? _buildCard(width, height, elevation, false)
                  : Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildCard(width, height, elevation, true),
                    ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildCard(double width, double height, double elevation, bool showFace) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isSelected 
              ? const Color(0xFFFFD700)
              : Colors.grey.shade300,
          width: widget.isSelected ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isSelected
                ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: elevation,
            offset: Offset(0, elevation / 2),
            spreadRadius: widget.isSelected ? 1 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: showFace && widget.cardId.isNotEmpty
            ? _buildFaceUpCard(width, height)
            : _buildCardBack(),
      ),
    );
  }
  
  Widget _buildFaceUpCard(double width, double height) {
    final rank = widget.cardId.substring(0, widget.cardId.length - 1);
    final suit = widget.cardId.substring(widget.cardId.length - 1);
    final isRed = (suit == '♥' || suit == '♦');
    final color = isRed ? const Color(0xFFD84315) : const Color(0xFF212121);
    
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(6 * widget.scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top corner
          Text(
            '$rank\n$suit',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13 * widget.scale,
              fontWeight: FontWeight.bold,
              height: 0.95,
            ),
          ),
          
          Expanded(
            child: Center(
              child: _buildSuitPattern(suit, color, width, height),
            ),
          ),
          
          // Bottom corner (rotated)
          Align(
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: math.pi,
              child: Text(
                '$rank\n$suit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 13 * widget.scale,
                  fontWeight: FontWeight.bold,
                  height: 0.95,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuitPattern(String suit, Color color, double width, double height) {
    // Center suit symbol
    return Text(
      suit,
      style: TextStyle(
        fontSize: 36 * widget.scale,
        color: color,
        fontWeight: FontWeight.w300,
      ),
    );
  }
  
  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF3B82F6),
            Color(0xFF1E3A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _CardBackPainter(),
        child: Center(
          child: Opacity(
            opacity: 0.2,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 32 * widget.scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Diamond pattern
    final spacing = 12.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final path = Path()
          ..moveTo(x + spacing / 2, y)
          ..lineTo(x + spacing, y + spacing / 2)
          ..lineTo(x + spacing / 2, y + spacing)
          ..lineTo(x, y + spacing / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
