import 'package:flutter/material.dart';

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
      title: const Text('Join channel'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Channel Name'),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a channel name';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Join')),
      ],
    );
  }
}
