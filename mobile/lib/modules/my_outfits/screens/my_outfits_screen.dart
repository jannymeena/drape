import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/titled_screen_header.dart';
import '../../favourites/widgets/favourites_view.dart';
import '../widgets/history_view.dart';

enum MyOutfitsTab { favourites, history }

/// My Outfits (Stitch `my_outfits_history` + `favourites_zoura`): a
/// Favourites | History switch over the two views. Opened from the heart on
/// Today (Favourites); `?tab=history` opens History.
class MyOutfitsScreen extends StatefulWidget {
  static const path = 'my-outfits';
  static const name = 'my_outfits';

  /// Route name kept for the old `/today/history` address (opens History).
  static const historyName = 'outfit_history';

  final MyOutfitsTab initialTab;
  const MyOutfitsScreen({super.key, this.initialTab = MyOutfitsTab.favourites});

  /// `tab` query value → tab ("history" → History, anything else → Favourites).
  static MyOutfitsTab tabFromQuery(String? tab) =>
      tab == 'history' ? MyOutfitsTab.history : MyOutfitsTab.favourites;

  @override
  State<MyOutfitsScreen> createState() => _MyOutfitsScreenState();
}

class _MyOutfitsScreenState extends State<MyOutfitsScreen> {
  late MyOutfitsTab _tab = widget.initialTab;

  /// Tabs opened so far. A tab is built on first visit (so History doesn't
  /// fetch or log "viewed" until it's actually seen), then kept alive.
  late final Set<MyOutfitsTab> _opened = {widget.initialTab};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TitledScreenHeader(
              title: 'My Outfits',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SegmentedTabs(
                tabs: const [
                  SegmentedTab('Favourites'),
                  SegmentedTab('History'),
                ],
                selected: _tab.index,
                onSelect: (i) => setState(() {
                  _tab = MyOutfitsTab.values[i];
                  _opened.add(_tab);
                }),
              ),
            ),
            Expanded(
              // Both views stay alive, so switching back keeps each one's
              // own tab / filter and scroll position.
              child: IndexedStack(
                index: _tab.index,
                children: [
                  if (_opened.contains(MyOutfitsTab.favourites))
                    const FavouritesView()
                  else
                    const SizedBox.shrink(),
                  if (_opened.contains(MyOutfitsTab.history))
                    const HistoryView()
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
