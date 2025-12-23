import 'package:flutter/material.dart';
import '../core/trick_engines.dart';
import '../ai/bidding_engine.dart';
import '../ai/play_engine.dart';
import '../ai/score_engine.dart';

class BridgeSettingsScreen extends StatefulWidget {
  final BridgeEngine engine;

  const BridgeSettingsScreen({super.key, required this.engine});

  @override
  State<BridgeSettingsScreen> createState() => _BridgeSettingsScreenState();
}

class _BridgeSettingsScreenState extends State<BridgeSettingsScreen> {
  late BiddingDifficulty _biddingDifficulty;
  late PlayDifficulty _playDifficulty;
  late int _maxTricks;
  late VulnerabilityCondition _vulnerability;

  @override
  void initState() {
    super.initState();
    _biddingDifficulty = widget.engine.biddingDifficulty;
    _playDifficulty = widget.engine.playDifficulty;
    _maxTricks = widget.engine.maxTricks;
    _vulnerability = widget.engine.vulnerability;
  }

  void _applySettings() {
    widget.engine.setBiddingDifficulty(_biddingDifficulty);
    widget.engine.setPlayDifficulty(_playDifficulty);
    widget.engine.setMaxTricks(_maxTricks);
    widget.engine.setVulnerability(_vulnerability);
    Navigator.pop(context);
  }

  IconData _getDifficultyIcon(dynamic difficulty) {
    final level = difficulty.toString().split('.').last;
    switch (level) {
      case 'easy':
        return Icons.sentiment_satisfied;
      case 'medium':
        return Icons.psychology;
      case 'hard':
        return Icons.military_tech;
      default:
        return Icons.help;
    }
  }

  Color _getDifficultyColor(dynamic difficulty) {
    final level = difficulty.toString().split('.').last;
    switch (level) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDifficultyLabel(dynamic difficulty) {
    final level = difficulty.toString().split('.').last;
    switch (level) {
      case 'easy':
        return 'Kolay';
      case 'medium':
        return 'Orta';
      case 'hard':
        return 'Zor';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Bot Ayarları',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bidding Difficulty
                    _buildSectionCard(
                      title: 'İhale Zekası',
                      icon: Icons.gavel,
                      iconColor: const Color(0xFF3B82F6),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: BiddingDifficulty.values.map((diff) {
                              final isSelected = _biddingDifficulty == diff;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: _buildDifficultyButton(
                                    difficulty: diff,
                                    isSelected: isSelected,
                                    onTap: () => setState(
                                      () => _biddingDifficulty = diff,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Play Difficulty
                    _buildSectionCard(
                      title: 'Oyun Zekası',
                      icon: Icons.casino,
                      iconColor: const Color(0xFFF59E0B),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: PlayDifficulty.values.map((diff) {
                              final isSelected = _playDifficulty == diff;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: _buildDifficultyButton(
                                    difficulty: diff,
                                    isSelected: isSelected,
                                    onTap: () =>
                                        setState(() => _playDifficulty = diff),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Max Tricks
                    _buildSectionCard(
                      title: 'Maksimum El',
                      icon: Icons.filter_9_plus,
                      iconColor: const Color(0xFF10B981),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            _maxTricks.toString(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          Slider(
                            value: _maxTricks.toDouble(),
                            min: 1,
                            max: 13,
                            divisions: 12,
                            activeColor: const Color(0xFF10B981),
                            inactiveColor: const Color(0xFF334155),
                            onChanged: (value) =>
                                setState(() => _maxTricks = value.toInt()),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Vulnerability
                    _buildSectionCard(
                      title: 'Zafiyet Durumu',
                      icon: Icons.shield,
                      iconColor: const Color(0xFFEF4444),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildVulnerabilityGrid(),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info Panel
                    _buildInfoPanel(),
                  ],
                ),
              ),
            ),

            // Apply Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _applySettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Ayarları Kaydet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDifficultyButton({
    required dynamic difficulty,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = _getDifficultyColor(difficulty);
    final icon = _getDifficultyIcon(difficulty);
    final label = _getDifficultyLabel(difficulty);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVulnerabilityGrid() {
    final options = [
      (VulnerabilityCondition.none, 'Yok', Icons.check_circle),
      (VulnerabilityCondition.ns, 'NS', Icons.people),
      (VulnerabilityCondition.ew, 'EW', Icons.groups),
      (VulnerabilityCondition.both, 'Her İki', Icons.groups_2),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = _vulnerability == opt.$1;
        return InkWell(
          onTap: () => setState(() => _vulnerability = opt.$1),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 96) / 2,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF334155),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  opt.$3,
                  color: isSelected ? Colors.white : const Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  opt.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Zorluk Seviyeleri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.sentiment_satisfied,
            Colors.green,
            'Kolay',
            'Basit kurallar ve sezgisel oyun',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.psychology,
            Colors.orange,
            'Orta',
            'Temel strateji ve sistem bilgisi',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.military_tech,
            Colors.red,
            'Zor',
            'İleri seviye taktikler ve planlama',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String title, String desc) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
