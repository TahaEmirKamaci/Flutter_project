import 'package:flutter/material.dart';

class SuitBadge extends StatelessWidget {
  final String suit; // '♠','♥','♦','♣','NT'
  final double size;
  const SuitBadge({super.key, required this.suit, this.size=24});

  @override
  Widget build(BuildContext context) {
    final isNT = suit.toUpperCase() == 'NT';
    Color fg;
    if (isNT) {
      fg = Colors.white;
    } else if (suit == '♥' || suit == '♦') {
      fg = const Color(0xFFE53935);
    } else {
      fg = const Color(0xFFEEEEEE);
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(size/2),
        border: Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: Text(isNT ? 'NT' : suit, style: TextStyle(
        color: fg,
        fontSize: isNT ? size*0.42 : size*0.6,
        fontWeight: FontWeight.w700,
        letterSpacing: isNT ? .5 : 0,
      )),
    );
  }
}
