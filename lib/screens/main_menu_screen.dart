import 'package:flutter/material.dart';
import '../core/game_core.dart';
import '../core/trick_engines.dart';
import 'game_table_screen.dart';
import 'bridge_settings_screen.dart';
import '../components/ui/round_button.dart';
import '../components/ui/popup_panel.dart';
import '../components/ui/menu_tile.dart';
import '../components/ui/suit_badge.dart';
import '../components/ui/sound_manager.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final _nameCtrl = TextEditingController();
  final _sound = CardSoundManager();
  String get _name => _nameCtrl.text.trim().isEmpty ? 'Player' : _nameCtrl.text.trim();
  
  // Bridge engine instance for settings
  final _bridgeEngine = BridgeEngine();

  void _open(GameEngine engine) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameTableScreen(engine: engine, playerName: _name),
    ));
  }

  void _showBotSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BridgeSettingsScreen(engine: _bridgeEngine),
    ));
  }



  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient + subtle decorations
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF0B1022), Color(0xFF131A35)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: -60, top: -40,
            child: Container(width: 220, height: 220, decoration: BoxDecoration(
              shape: BoxShape.circle, color: const Color(0xFF1E3A8A).withOpacity(.25))),
          ),
          Positioned(
            left: -80, bottom: -60,
            child: Container(width: 260, height: 260, decoration: BoxDecoration(
              shape: BoxShape.circle, color: const Color(0xFF047857).withOpacity(.22))),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Kart Oyunları', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('İsminizi girin ve bir oyun seçin', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: isWide ? 320 : 260,
                                child: TextField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.person_outline),
                                    suffixIcon: _nameCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: (){ setState(()=> _nameCtrl.clear()); }) : null,
                                    hintText: 'İsminiz',
                                    filled: true,
                                    fillColor: const Color(0xFF0B1226),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Bot Settings Button
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _showBotSettings,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.smart_toy, color: Colors.white, size: 22),
                                          SizedBox(width: 8),
                                          Text(
                                            'Bot Ayarları',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Tiles grid
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, c){
                                  final cross = c.maxWidth > 720 ? 2 : 1;
                                  return GridView(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross,
                                      mainAxisSpacing: 16, crossAxisSpacing: 16,
                                      childAspectRatio: isWide ? 2.8 : 2.4,
                                    ),
                                    children: [
                                      MenuTile(
                                        emoji: '♣️',
                                        title: 'Briç',
                                        subtitle: 'Profesyonel AI ile klasik briç',
                                        colors: const [Color(0xFF1E3A8A), Color(0xFF0B4BB3)],
                                        onTap: ()=> _open(_bridgeEngine),
                                        trailing: Wrap(spacing: 6, children: const [
                                          SuitBadge(suit: '♠', size: 22),
                                          SuitBadge(suit: '♥', size: 22),
                                          SuitBadge(suit: '♦', size: 22),
                                          SuitBadge(suit: '♣', size: 22),
                                          SuitBadge(suit: 'NT', size: 22),
                                        ]),
                                      ),
                                      MenuTile(
                                        emoji: '🂡',
                                        title: 'Hoşkin',
                                        subtitle: 'Özel oyun (beta)',
                                        colors: const [Color(0xFF047857), Color(0xFF065F46)],
                                        onTap: () {
                                          // Placeholder: open Bridge for now or show a dialog
                                          showDialog(context: context, builder: (ctx){
                                            return AlertDialog(
                                              backgroundColor: const Color(0xFF0B1226),
                                              title: const Text('Hoşkin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              content: const Text('Hoşkin oyunu yakında eklenecek.', style: TextStyle(color: Colors.white70)),
                                              actions: [
                                                TextButton(onPressed: ()=> Navigator.of(ctx).pop(), child: const Text('Kapat')),
                                              ],
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Replacement text for removed Pişti & Batak buttons
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B1226),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                'hoşkin',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
