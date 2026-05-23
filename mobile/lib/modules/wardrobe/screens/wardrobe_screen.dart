import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/wardrobe_item.dart';
import '../wardrobe_controller.dart';
import '../wardrobe_service.dart';
import '../widgets/add_to_wardrobe_chooser.dart';
import '../widgets/capacity_warning_banner.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/item_card.dart';
import 'batch_upload_screen.dart';
import 'item_detail_screen.dart';
import 'manual_entry_screen.dart' as wardrobe_manual;
import 'scanner_screen.dart';
import 'weekly_recap_screen.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  static const path = '/wardrobe';
  static const name = 'wardrobe';

  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(wardrobeControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);
    final controller = ref.read(wardrobeControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              onAdd: _openAddSheet,
              onInsights: () => context.goNamed(WeeklyRecapScreen.name),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Text(
                        'Wardrobe',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SearchField(onChanged: controller.setSearch),
                    ),
                    const SizedBox(height: 16),
                    ..._buildCapacityBanner(),
                    CategoryFilterChips(
                      categories:
                          WardrobeCategoryFilter.values.map((f) => f.label).toList(),
                      selectedIndex: state.category.index,
                      onSelected: (i) => controller
                          .selectCategory(WardrobeCategoryFilter.values[i]),
                    ),
                    const SizedBox(height: 16),
                    ..._buildBody(context, state, controller),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    WardrobeState state,
    WardrobeController controller,
  ) {
    if (state.loading && !state.hasData) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.espresso),
          ),
        ),
      ];
    }

    if (state.error != null && !state.hasData) {
      return [
        _MessageBlock(
          message: state.error!.message,
          actionLabel: 'Try again',
          onAction: controller.load,
        ),
      ];
    }

    final items = state.visibleItems;
    if (items.isEmpty) {
      final searching = state.search.trim().isNotEmpty;
      return [
        _MessageBlock(
          message: searching
              ? 'No pieces match "${state.search.trim()}".'
              : 'No pieces here yet. Add your first item to get started.',
        ),
        if (!searching) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _GrowYourWardrobeCard(onAdd: _openAddSheet),
          ),
        ],
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (_, i) => ItemCard(
            item: _toCardData(items[i]),
            onTap: () => context.goNamed(
              ItemDetailScreen.name,
              pathParameters: {'id': items[i].id},
            ),
            onFavorite: () => _onFavorite(items[i].id),
          ),
        ),
      ),
      // "Load more" only when there are unloaded server pages and no active
      // client-side search (search filters the loaded set, not the server).
      if (state.hasMore && state.search.trim().isEmpty) ...[
        const SizedBox(height: 16),
        Center(
          child: state.loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(color: AppColors.espresso),
                )
              : TextButton(
                  onPressed: controller.loadMore,
                  child: const Text('Load more'),
                ),
        ),
      ],
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _GrowYourWardrobeCard(onAdd: _openAddSheet),
      ),
    ];
  }

  /// Capacity warning banner (free tier only, at/above the soft threshold).
  /// Best-effort: while loading or on error, render nothing.
  List<Widget> _buildCapacityBanner() {
    final capacity = ref.watch(wardrobeCapacityProvider).valueOrNull;
    if (capacity == null || !capacity.shouldShowBanner) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CapacityWarningBanner(
          used: capacity.used,
          total: capacity.cap,
          level: switch (capacity.level) {
            'blocked' => CapacityLevel.blocked,
            'urgent' => CapacityLevel.urgent,
            _ => CapacityLevel.soft,
          },
          onUpgrade: () => debugPrint('wardrobe: upgrade'),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _onFavorite(String itemId) async {
    try {
      await ref.read(wardrobeControllerProvider.notifier).toggleFavorite(itemId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  WardrobeItemData _toCardData(WardrobeItem item) => WardrobeItemData(
        id: item.id,
        name: item.name,
        category: item.categoryLabel,
        imageUrl: item.displayImageUrl,
        favorited: item.isFavorite,
        starter: item.isStarterWardrobe,
      );

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: AddToWardrobeChooser(
                    // Capacity (used/remaining) deferred to SP2.
                    onUpgrade: () => debugPrint('add: upgrade'),
                    onChoice: (choice) {
                      Navigator.of(ctx).pop();
                      switch (choice) {
                        case AddToWardrobeChoice.upload:
                          context.goNamed(BatchUploadScreen.name);
                        case AddToWardrobeChoice.scan:
                          context.goNamed(ScannerScreen.name);
                        case AddToWardrobeChoice.manual:
                          context.goNamed(
                            wardrobe_manual.ManualEntryScreen.name,
                          );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onInsights;
  const _TopBar({required this.onAdd, required this.onInsights});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Text(
            'DRAPE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.espresso,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.insights_outlined, color: AppColors.espresso),
            onPressed: onInsights,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.espresso),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.taupe, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search your pieces...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.taupe,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageBlock({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
      child: Column(
        children: [
          const Icon(Icons.checkroom_outlined,
              color: AppColors.taupeSoft, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _GrowYourWardrobeCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _GrowYourWardrobeCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.taupeSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.ivoryDim,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add, color: AppColors.espresso),
          ),
          const SizedBox(height: 12),
          Text(
            'Grow Your Wardrobe',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Digitize your favorite pieces to unlock personalized styling recommendations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.espresso,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Add New Item',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
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
