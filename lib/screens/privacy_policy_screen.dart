import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lispinto_chat/widgets/scrollable_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:lispinto_chat/core/app_localizations.dart';

/// A screen that displays the app's privacy policy.
///
/// The content is loaded from the bundled `PRIVACY_POLICY.md` asset, so any
/// changes to that file are reflected automatically after a rebuild.
final class PrivacyPolicyScreen extends StatefulWidget {
  /// Creates a [PrivacyPolicyScreen].
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

final class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final Future<String> _markdownFuture;

  @override
  void initState() {
    super.initState();
    _markdownFuture = rootBundle.loadString('PRIVACY_POLICY.md');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).privacyPolicy)),
      body: FutureBuilder<String>(
        future: _markdownFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                AppLocalizations.of(context).failedToLoadPrivacyPolicy,
              ),
            );
          }

          return ScrollableScreen(
            maxWidth: 600.0,
            mainChild: MarkdownBody(
              data: snapshot.data!,
              onTapLink: (text, href, title) {
                if (href != null) {
                  launchUrlString(href);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
