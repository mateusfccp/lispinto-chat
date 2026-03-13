import 'package:flutter/material.dart';
import 'package:lispinto_chat/core/app_localizations.dart';

/// A dialog that allows the user to input a channel name to join or create.
final class JoinChannelDialog extends StatefulWidget {
  /// Creates a [JoinChannelDialog].
  const JoinChannelDialog({required this.onJoin, super.key});

  /// Called when the user submits a channel name.
  final ValueChanged<String> onJoin;

  @override
  State<JoinChannelDialog> createState() => _JoinChannelDialogState();
}

class _JoinChannelDialogState extends State<JoinChannelDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _controller.text.trim();
      if (name.isNotEmpty) {
        widget.onJoin(name);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).joinChannel),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).channelName,
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context).pleaseEnterChannelName;
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(AppLocalizations.of(context).join),
        ),
      ],
    );
  }
}
