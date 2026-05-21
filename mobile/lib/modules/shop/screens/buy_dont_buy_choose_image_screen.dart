import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'buy_dont_buy_verdict_buy_screen.dart';

class ChooseProductImageScreen extends StatefulWidget {
  static const path = 'buy-dont-buy/choose-image';
  static const name = 'shop_buy_dont_buy_choose_image';

  const ChooseProductImageScreen({super.key});

  @override
  State<ChooseProductImageScreen> createState() =>
      _ChooseProductImageScreenState();
}

class _ChooseProductImageScreenState extends State<ChooseProductImageScreen> {
  int _selected = 0;
  static const _labels = [
    'STUDIO SHOT',
    'ON MODEL',
    'FABRIC DETAIL',
    'SIDE VIEW',
    'VARIANT: CHARCOAL',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select the exact image you want to analyze',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _labels.length + 1,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (_, i) {
                  if (i == _labels.length) return const _AddImageTile();
                  return _ImageTile(
                    label: _labels[i],
                    selected: _selected == i,
                    onTap: () => setState(() => _selected = i),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: AppColors.ivoryWarm,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => context.pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 52,
                            child: Center(
                              child: Text('BACK',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.inkSoft,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700,
                                      )),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Material(
                        color: AppColors.espresso,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => context
                              .goNamed(BuyDontBuyVerdictBuyScreen.name),
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 52,
                            child: Center(
                              child: Text('CONTINUE',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.white,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700,
                                      )),
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

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text('Choose Product Image',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
          const Icon(Icons.help_outline, color: AppColors.espresso),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ImageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? AppColors.espresso : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.checkroom_outlined,
                        color: AppColors.taupeSoft, size: 36),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.espresso,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: AppColors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.taupe,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.taupeSoft),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.espresso, size: 28),
                const SizedBox(height: 6),
                Text('ADD IMAGE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 14),
      ],
    );
  }
}
