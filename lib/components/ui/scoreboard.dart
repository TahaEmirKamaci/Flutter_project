import 'package:flutter/material.dart';

class ScoreBoard extends StatelessWidget {
  final Map<String, int> scores;
  const ScoreBoard({super.key, required this.scores});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: scores.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(e.value.toString()),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
