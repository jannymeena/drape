import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

class BatchUploadScreen extends StatelessWidget {
  static const path = 'batch-upload';
  static const name = 'wardrobe_batch_upload';

  const BatchUploadScreen({super.key});

  static const _tiles = <_BatchTile>[
    _BatchTile(category: 'SHIRT', confident: true),
    _BatchTile(category: 'JEANS', confident: true),
    _BatchTile(category: 'OUTERWEAR', confident: false),
    _BatchTile(category: 'SHOES', confident: true),
    _BatchTile(category: 'SHIRT', confident: true),
    _BatchTile(category: 'PANTS', confident: true),
    _BatchTile(category: 'SHIRT', confident: true),
    _BatchTile(category: 'KNITWEAR', confident: true),
    _BatchTile(category: 'DENIM', confident: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            _ProgressLabel(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AddPhotosTile(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tiles.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (_, i) => _BatchItemTile(tile: _tiles[i]),
              ),
            ),
            _BottomBar(
              onAddMore: () => debugPrint('batch: pick more'),
              onContinue: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Add to Wardrobe',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: () => debugPrint('batch: done'),
            child: Text(
              'Done',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'SCANNING ASSETS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.taupe,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            '12 items added',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotosTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DottedTile(
      onTap: () => debugPrint('batch: tap to add photos'),
    );
  }
}

class DottedTile extends StatelessWidget {
  final VoidCallback onTap;
  const DottedTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryDim,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.taupeSoft,
              style: BorderStyle.solid,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.espresso, size: 28),
              const SizedBox(height: 8),
              Text(
                'Tap to add photos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchTile {
  final String category;
  final bool confident;
  const _BatchTile({required this.category, required this.confident});
}

class _BatchItemTile extends StatelessWidget {
  final _BatchTile tile;
  const _BatchItemTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.checkroom_outlined,
              color: AppColors.taupeSoft,
              size: 36,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: tile.confident
                    ? AppColors.sage
                    : const Color(0xFFC8901C),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                tile.confident ? Icons.check : Icons.priority_high,
                color: AppColors.white,
                size: 12,
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.espresso,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      tile.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const Icon(Icons.edit,
                      color: AppColors.brandText, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onAddMore;
  final VoidCallback onContinue;
  const _BottomBar({required this.onAddMore, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Material(
              color: AppColors.espresso,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAddMore,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.add_a_photo_outlined,
                      color: AppColors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: AppColors.espresso,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onContinue,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward,
                              color: AppColors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
