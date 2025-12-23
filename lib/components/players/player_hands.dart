import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/card_widgets.dart';

class PlayerHand extends StatelessWidget {
  final List<String> cards;
  final Set<int> playable;
  final int? selectedIndex;
  final void Function(int) onSelect;
  final void Function(int)? onDoubleTap;
  final double fanSpread; // Controls curve intensity
  const PlayerHand({
    super.key,
    required this.cards,
    required this.playable,
    required this.selectedIndex,
    required this.onSelect,
    this.onDoubleTap,
    this.fanSpread = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox(height: 110);

    // Fan layout parameters
    final cardCount = cards.length;
    final maxAngle =
        0.4 * fanSpread; // Maximum rotation angle in radians (adjustable)
    final arcRadius = 400.0 * fanSpread; // Radius of the arc
    final cardWidth = 64.0;
    final cardHeight = 92.0;

    // Calculate positions for fan layout
    final angleStep = cardCount > 1 ? (2 * maxAngle) / (cardCount - 1) : 0.0;
    final startAngle = -maxAngle;

    // Calculate bounding box
    final positions = <Map<String, dynamic>>[];
    double minX = 0, maxX = 0, minY = 0, maxY = 0;

    for (var i = 0; i < cardCount; i++) {
      final angle = startAngle + i * angleStep;
      // Position along arc
      final x = arcRadius * math.sin(angle);
      final y = arcRadius * (1 - math.cos(angle));

      positions.add({'x': x, 'y': y, 'angle': angle});

      // Update bounds
      if (i == 0) {
        minX = maxX = x;
        minY = maxY = y;
      } else {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }

    final totalWidth = maxX - minX + cardWidth;
    final totalHeight =
        maxY - minY + cardHeight + 20; // Extra space for raised cards
    final offsetX = -minX;
    final offsetY = -minY;

    return SizedBox(
      height: totalHeight,
      child: Center(
        child: SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < cardCount; i++)
                Positioned(
                  left: positions[i]['x'] + offsetX,
                  top:
                      positions[i]['y'] +
                      offsetY -
                      (selectedIndex == i ? 20 : 0), // Raise selected card
                  child: Transform.rotate(
                    angle: positions[i]['angle'],
                    child: CardWidget(
                      label: cards[i],
                      raised: selectedIndex == i,
                      selectable: playable.contains(i),
                      selected: selectedIndex == i,
                      onTap: () => onSelect(i),
                      onDoubleTap: onDoubleTap != null
                          ? () => onDoubleTap!(i)
                          : null,
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

/// Horizontal opponent hand (top player)
class OpponentHandHorizontal extends StatelessWidget {
  final int cardCount;
  const OpponentHandHorizontal({super.key, required this.cardCount});
  @override
  Widget build(BuildContext context) {
    final visible = cardCount.clamp(0, 14);
    if (visible == 0) return const SizedBox.shrink();
    final totalWidth = 64.0 + (visible - 1) * 18.0;
    return SizedBox(
      width: totalWidth,
      height: 92,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(left: i * 18.0, child: const CardBackWidget()),
        ],
      ),
    );
  }
}

/// Vertical opponent hand (left/right players)
class OpponentHandVertical extends StatelessWidget {
  final int cardCount;
  const OpponentHandVertical({super.key, required this.cardCount});
  @override
  Widget build(BuildContext context) {
    final visible = cardCount.clamp(0, 14);
    if (visible == 0) return const SizedBox.shrink();
    final totalHeight = 92.0 + (visible - 1) * 6.0;
    return SizedBox(
      width: 64,
      height: totalHeight,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(top: i * 6.0, child: const CardBackWidget()),
        ],
      ),
    );
  }
}

// Legacy alias for backward compatibility
class OpponentHand extends StatelessWidget {
  final int cardCount;
  const OpponentHand({super.key, required this.cardCount});
  @override
  Widget build(BuildContext context) =>
      OpponentHandHorizontal(cardCount: cardCount);
}

class PlayerAvatar extends StatelessWidget {
  final String name;
  final bool active;
  final String? role; // Declarer, Dummy, Defender
  const PlayerAvatar({
    super.key,
    required this.name,
    this.active = false,
    this.role,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF2E7D32)
            : Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? Colors.white : Colors.white24,
          width: 1.4,
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: Text(name.isNotEmpty ? name.substring(0, 1) : '?'),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (role != null)
                Text(
                  role!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
