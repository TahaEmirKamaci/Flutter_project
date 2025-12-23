import 'package:flutter/material.dart';

class RoundButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  const RoundButton({super.key, required this.label, this.onPressed, this.color=const Color(0xFF1E3A8A)});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
