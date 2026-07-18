import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../settings_service.dart';

/// Export status — combines the "request form" and "history added" mockup
/// variants into a single screen with state.
enum _ExportStatus { idle, preparing, ready }

class ExportMyDataScreen extends ConsumerStatefulWidget {
  static const path = 'export';
  static const name = 'profile_export';

  const ExportMyDataScreen({super.key});

  @override
  ConsumerState<ExportMyDataScreen> createState() =>
      _ExportMyDataScreenState();
}

class _ExportMyDataScreenState extends ConsumerState<ExportMyDataScreen> {
  _ExportStatus _status = _ExportStatus.idle;
  Map<String, dynamic>? _data;

  /// Fetch the portable JSON snapshot from `GET /account/export`.
  Future<void> _onRequest() async {
    setState(() => _status = _ExportStatus.preparing);
    try {
      final data = await ref.read(settingsServiceProvider).exportData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = _ExportStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _ExportStatus.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't prepare your export. Try again."),
        ),
      );
    }
  }

  /// Write the snapshot to a temp .json file and hand it to the OS share sheet
  /// (covers email, Drive, Files, etc.).
  Future<void> _shareExport() async {
    final data = _data;
    if (data == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final stamp =
          DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');
      final file = File('${dir.path}/drape_export_$stamp.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'My ZOURA data export',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't share the export.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _RequestCard(
                    onRequest: _status == _ExportStatus.idle ? _onRequest : null,
                    requested: _status != _ExportStatus.idle,
                  ),
                  const SizedBox(height: 16),
                  if (_status == _ExportStatus.preparing) ...[
                    const _PreparingCard(),
                    const SizedBox(height: 16),
                  ] else if (_status == _ExportStatus.ready) ...[
                    _ReadyCard(onDownload: _shareExport),
                    const SizedBox(height: 24),
                    Text(
                      'DELIVERY METHODS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _DeliveryTile(
                      icon: Icons.mail_outline,
                      label: 'Email download link to me',
                      onTap: _shareExport,
                    ),
                    const SizedBox(height: 10),
                    _DeliveryTile(
                      icon: Icons.cloud_outlined,
                      label: 'Save to my Google Drive',
                      onTap: _shareExport,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    "WHAT'S INCLUDED IN YOUR EXPORT",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _IncludedTile(
                    icon: Icons.checkroom,
                    label: 'Wardrobe items (name, category, color, CPW)',
                  ),
                  _IncludedTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Outfit logs (date, items worn, occasion)',
                  ),
                  _IncludedTile(
                    icon: Icons.straighten,
                    label: 'Body measurements (if provided)',
                  ),
                  _IncludedTile(
                    icon: Icons.palette_outlined,
                    label: 'Style profile preferences',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.table_chart_outlined,
                            color: AppColors.taupe, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Format: .CSV file — opens in Excel, Google Sheets, or Numbers.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Export My Data',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final VoidCallback? onRequest;
  final bool requested;
  const _RequestCard({required this.onRequest, required this.requested});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.ivoryWarm,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.file_download_outlined,
                color: AppColors.espresso, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            'Export Your Wardrobe Data',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'A complete archive of your items, logs, and style profile.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESTIMATED SIZE: 45 MB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'CSV Format',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.espresso,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: requested
                ? AppColors.taupe.withValues(alpha: 0.4)
                : AppColors.espresso,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onRequest,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Center(
                  child: Text(
                    requested ? 'Export Requested' : 'Request My Export',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
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

class _PreparingCard extends StatelessWidget {
  const _PreparingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageDim.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              backgroundColor: AppColors.white,
              valueColor: AlwaysStoppedAnimation(AppColors.sage),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preparing your export…',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.sage,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Gathering your wardrobe, logs, and profile',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sageContent,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  final VoidCallback onDownload;
  const _ReadyCard({required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageDim.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.sage, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to Download',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.sage,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Your archive is prepared for download',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sageContent,
                      ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.sage,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onDownload,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download,
                        color: AppColors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'download',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DeliveryTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncludedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IncludedTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.espresso, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
