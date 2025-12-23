import 'package:flutter/material.dart';
import '../ui/suit_badge.dart';
import '../ui/round_button.dart';

class BiddingDialog extends StatefulWidget {
  final List<String> bidHistory;
  final int currentBidderIndex;
  final int contractLevel;
  final String? contractTrump;
  final void Function(int level, String? trump, bool pass) onBid;
  final List<int>? tricksWon; // Optional: tricks won by each player

  const BiddingDialog({
    super.key,
    required this.bidHistory,
    required this.currentBidderIndex,
    required this.contractLevel,
    required this.contractTrump,
    required this.onBid,
    this.tricksWon,
  });

  @override
  State<BiddingDialog> createState() => _BiddingDialogState();
}

class _BiddingDialogState extends State<BiddingDialog> {
  @override
  void initState() {
    super.initState();
    // Trigger bot bid if it's not player's turn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBotBidIfNeeded();
    });
  }

  @override
  void didUpdateWidget(BiddingDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When dialog updates, check if bot needs to bid
    if (widget.currentBidderIndex != oldWidget.currentBidderIndex) {
      _triggerBotBidIfNeeded();
    }
  }

  void _triggerBotBidIfNeeded() {
    if (widget.currentBidderIndex != 0) {
      // It's a bot's turn - trigger the onBid which will call engine's auto-bid
      // The engine will handle the actual bot logic
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && widget.currentBidderIndex != 0) {
          // This will trigger the engine's auto-bid mechanism
          // by just waiting - the engine should handle it via _maybeAutoBid
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seats = ['Player', 'East', 'North', 'West'];
    
    return Dialog(
      backgroundColor: const Color(0xFF0B1226),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 520),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Row(
                children: [
                  Icon(Icons.gavel, color: Color(0xFF60A5FA), size: 28),
                  SizedBox(width: 12),
                  Text(
                    'İHALE MASASI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Sıra: ${seats[widget.currentBidderIndex]}',
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.currentBidderIndex != 0) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Düşünüyor...',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: 24, color: Colors.white12),
              
              // Bidding history - grouped by turns (rows per round)
              if (widget.bidHistory.isNotEmpty) ...[
                const Text(
                  'İhale Geçmişi (Turlar):',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _BidHistoryTable(bids: widget.bidHistory, seats: seats),
                const SizedBox(height: 16),
              ],

              // Modern grid bidding panel
              const Text(
                'İhale Seçin:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _BiddingGrid(
                enabled: widget.currentBidderIndex == 0,
                contractLevel: widget.contractLevel,
                contractTrump: widget.contractTrump,
                onSelect: (l, s) => widget.onBid(l, s, false),
              ),
              const SizedBox(height: 14),
              _ActionBar(
                enabled: widget.currentBidderIndex == 0,
                onPass: () => widget.onBid(0, null, true),
                onDouble: () => widget.onBid(-1, 'X', false),
                onRedouble: () => widget.onBid(-2, 'XX', false),
                onHint: (){},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BidChip extends StatelessWidget {
  final String bid;
  const _BidChip({required this.bid});

  @override
  Widget build(BuildContext context) {
    if (bid.toLowerCase() == 'pass') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          bid,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
    }
    // Parse level and suit
    final level = bid[0];
    final suitText = bid.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            level,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          SuitBadge(suit: suitText, size: 14),
        ],
      ),
    );
  }
}

class _BidButton extends StatelessWidget {
  final int level;
  final String? suit; // null => NT
  final bool enabled;
  final int contractLevel;
  final String? contractTrump;
  final void Function(int, String?) onSelect;

  const _BidButton({
    required this.level,
    required this.suit,
    required this.enabled,
    required this.contractLevel,
    required this.contractTrump,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final order = ['♣', '♦', '♥', '♠', null];
    int rank(int lvl, String? s) => (lvl - 1) * 5 + order.indexOf(s);
    final currentRank = contractLevel == 0 ? -1 : rank(contractLevel, contractTrump);
    final myRank = rank(level, suit);
    final allowed = myRank > currentRank;

    final palette = {
      '♠': const Color(0xFF0B132B), // navy/black
      '♥': const Color(0xFF8B1D1D), // deep red
      '♦': const Color(0xFFD97706), // amber/orange
      '♣': const Color(0xFF14532D), // deep green
      null: const Color(0xFF1E3A8A), // NT: blue
    };
    final base = palette[suit];
    final bg = enabled && allowed ? base!.withOpacity(.85) : const Color(0xFF1F2937);
    final border = enabled && allowed ? Colors.white24 : Colors.white12;

    return InkWell(
      onTap: enabled && allowed ? () => onSelect(level, suit) : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: 64,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (enabled && allowed)
              BoxShadow(color: base!.withOpacity(.35), blurRadius: 6, spreadRadius: 0, offset: const Offset(0, 2)),
          ],
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              level.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            SuitBadge(suit: suit ?? 'NT', size: 16),
          ],
        ),
      ),
    );
  }
}

class _BidHistoryTable extends StatelessWidget {
  final List<String> bids;
  final List<String> seats;
  const _BidHistoryTable({required this.bids, required this.seats});

  @override
  Widget build(BuildContext context) {
    // Group bids into rounds of 4 (Player, East, North, West)
    final rows = <List<String>>[];
    for (int i = 0; i < bids.length; i += 4) {
      rows.add(bids.sublist(i, (i + 4) > bids.length ? bids.length : i + 4));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              for (int s = 0; s < 4; s++)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, size: 14, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 6),
                      Text(seats[s], style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (int r = 0; r < rows.length; r++) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1226).withOpacity(.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                children: [
                  for (int c = 0; c < 4; c++)
                    Expanded(
                      child: Center(
                        child: c < rows[r].length
                            ? _BidChip(bid: rows[r][c])
                            : const Text('-', style: TextStyle(color: Colors.white24)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BiddingGrid extends StatelessWidget {
  final bool enabled;
  final int contractLevel;
  final String? contractTrump;
  final void Function(int, String?) onSelect;
  const _BiddingGrid({
    required this.enabled,
    required this.contractLevel,
    required this.contractTrump,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final suits = [null, '♠', '♥', '♦', '♣']; // SA/NT first column
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - 24) / suits.length; // 12px side padding
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1226).withOpacity(.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in suits)
                SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Column header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SuitBadge(suit: s ?? 'NT', size: 18),
                            const SizedBox(width: 6),
                            Text(
                              s == null ? 'SA' : s,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Levels 1..7
                      for (int lvl=1; lvl<=7; lvl++) ...[
                        _BidButton(
                          level: lvl,
                          suit: s,
                          enabled: enabled,
                          contractLevel: contractLevel,
                          contractTrump: contractTrump,
                          onSelect: onSelect,
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPass;
  final VoidCallback onDouble;
  final VoidCallback onRedouble;
  final VoidCallback onHint;
  const _ActionBar({
    required this.enabled,
    required this.onPass,
    required this.onDouble,
    required this.onRedouble,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    Widget actionButton(String label, Color bg, VoidCallback? onTap) {
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: enabled ? bg : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            boxShadow: [BoxShadow(color: bg.withOpacity(.25), blurRadius: 8, offset: const Offset(0,2))],
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        actionButton('X', const Color(0xFF8B1D1D), enabled ? onDouble : null),
        actionButton('PAS', const Color(0xFF374151), enabled ? onPass : null),
        actionButton('XX', const Color(0xFFD97706), enabled ? onRedouble : null),
        actionButton('?', const Color(0xFF1E3A8A), enabled ? onHint : null),
      ],
    );
  }
}
