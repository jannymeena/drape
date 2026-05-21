import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'manual_entry_screen.dart' as wardrobe_manual;

class ScannerScreen extends StatelessWidget {
  static const path = 'scan';
  static const name = 'wardrobe_scanner';

  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _ViewfinderBackground()),
            const Positioned.fill(child: _Reticle()),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: _TopBar(onClose: () => context.pop()),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConfidenceChip(label: '87% confident: Oxford Shirt'),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => context.goNamed(
                        wardrobe_manual.ManualEntryScreen.name,
                      ),
                      child: Text(
                        "NOT SURE? ENTER DETAILS MANUALLY",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.brandText.withValues(alpha: 0.6),
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.espresso,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          debugPrint('scanner: add this item');
                          context.pop();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Center(
                            child: Text(
                              'ADD THIS ITEM',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        _CircleIconButton(icon: Icons.close, onTap: onClose),
        const Spacer(),
        Text(
          'SCAN ITEM',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.brandText,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        _CircleIconButton(icon: Icons.flash_on, onTap: () {}),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.brandText, size: 20),
      ),
    );
  }
}

class _ViewfinderBackground extends StatelessWidget {
  const _ViewfinderBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A130C), Color(0xFF3B2A1F), Color(0xFF1A130C)],
        ),
      ),
    );
  }
}

class _Reticle extends StatelessWidget {
  const _Reticle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.brandText.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              ..._Corner.values.map((c) => _ReticleCorner(corner: c)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Corner { tl, tr, bl, br }

class _ReticleCorner extends StatelessWidget {
  final _Corner corner;
  const _ReticleCorner({required this.corner});

  @override
  Widget build(BuildContext context) {
    const len = 22.0;
    const thick = 3.0;
    final br = switch (corner) {
      _Corner.tl =>
        const BorderRadius.only(topLeft: Radius.circular(28)),
      _Corner.tr =>
        const BorderRadius.only(topRight: Radius.circular(28)),
      _Corner.bl =>
        const BorderRadius.only(bottomLeft: Radius.circular(28)),
      _Corner.br =>
        const BorderRadius.only(bottomRight: Radius.circular(28)),
    };

    final top = corner == _Corner.tl || corner == _Corner.tr;
    final left = corner == _Corner.tl || corner == _Corner.bl;

    return Positioned(
      top: top ? 0 : null,
      bottom: !top ? 0 : null,
      left: left ? 0 : null,
      right: !left ? 0 : null,
      child: Container(
        width: len + thick,
        height: len + thick,
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border(
            top: top
                ? const BorderSide(color: AppColors.gold, width: thick)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: AppColors.gold, width: thick)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: AppColors.gold, width: thick)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: AppColors.gold, width: thick)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final String label;
  const _ConfidenceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sageDim.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.sage, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.sageContent,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
