import 'package:flutter/material.dart';

class MenuTile extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  final Widget? trailing; // optional trailing widget (badges row)
  const MenuTile({super.key, required this.emoji, required this.title, required this.subtitle, required this.colors, required this.onTap, this.trailing});

  @override
  State<MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<MenuTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    // On hover slightly rotate and shift gradient for a subtle dynamic feel
    final baseColors = widget.colors;
    final shifted = _hover ? baseColors.map((c)=> c.withOpacity(0.92)).toList() : baseColors;
    final gradient = LinearGradient(
      colors: shifted,
      begin: _hover ? Alignment.topRight : Alignment.topLeft,
      end: _hover ? Alignment.bottomLeft : Alignment.bottomRight,
    );
    return MouseRegion(
      onEnter: (_) => setState(()=> _hover = true),
      onExit: (_) => setState(()=> _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, _hover ? -4.0 : 0.0)
            ..scale(_hover ? 1.02 : 1.0),
          child: Stack(
            children: [
              // Base tile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: baseColors.last.withOpacity(_hover? .40 : .25), blurRadius: _hover? 18 : 12, offset: const Offset(0,8)),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      alignment: Alignment.center,
                      child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(widget.subtitle, style: TextStyle(color: Colors.white.withOpacity(.9))),
                        ],
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _hover ? 0.30 : 0.0,
                    curve: Curves.easeOutCubic,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(.08)),
                      ),
                    ),
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
