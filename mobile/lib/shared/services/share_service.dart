import 'package:share_plus/share_plus.dart';

/// Thin wrapper over the OS share sheet (`share_plus`). Centralizes the one
/// import so screens just build a string. The sheet itself offers Instagram,
/// Messages, etc. when those apps are installed.
///
/// Sharing a rendered image (e.g. a recap card) is a future enhancement; v1
/// shares text only.
Future<void> shareText(String text, {String? subject}) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}
