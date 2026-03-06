import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lispinto_chat/core/responsive.dart';
import 'package:lispinto_chat/core/router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/services/image_upload_service.dart';
import 'package:lispinto_chat/widgets/autocomplete_dropdown.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/channel_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/command_autocomplete_trigger.dart';
import 'package:lispinto_chat/widgets/autocomplete_triggers/tag_autocomplete_trigger.dart';
import 'package:prototype_constrained_box/prototype_constrained_box.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../core/get_nickname_color.dart';

enum _AttachmentOption { uploadPhoto }

/// A widget that provides the input area for typing and sending messages,
/// including image uploads and autocomplete.
final class InputArea extends StatefulWidget {
  /// Creates an [InputArea].
  const InputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.provider,
    required this.onSend,
  });

  /// The controller for the text field.
  final TextEditingController controller;

  /// The focus node for the text field.
  final FocusNode focusNode;

  /// The provider that manages the chat state.
  final ChatProvider provider;

  /// Callback when a message is sent.
  final VoidCallback onSend;

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  bool _isUploading = false;

  Future<void> _uploadImage(Uint8List imageBytes) async {
    final imgbbApiKey = locator<UserConfiguration>().imgbbApiKey.trim();
    if (imgbbApiKey.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ImgBB API Key Required'),
            content: const Text(
              'To upload images, please configure your ImgBB API Key in the settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  const ConfigurationsRoute().push(context);
                },
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    try {
      final uploadService = locator<ImageUploadService>();
      final url = await uploadService.uploadImage(imageBytes);
      final currentText = widget.controller.text;
      if (currentText.isEmpty) {
        widget.controller.text = url;
      } else {
        widget.controller.text = '$currentText $url';
      }
      widget.focusNode.requestFocus();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $exception')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      await _uploadImage(bytes);
    }
  }

  Future<void> _handleSuperClipboardPaste() async {
    final clipboard = SystemClipboard.instance;
    bool uploaded = false;

    if (clipboard != null) {
      final imgbbApiKey = locator<UserConfiguration>().imgbbApiKey.trim();
      final canUpload = imgbbApiKey.isNotEmpty;

      final reader = await clipboard.read();

      for (final item in reader.items) {
        if (canUpload && item.canProvide(Formats.fileUri)) {
          final uri = await item.readValue(Formats.fileUri);
          if (uri != null) {
            final path = uri.toFilePath().toLowerCase();
            if (path.endsWith('.png') ||
                path.endsWith('.jpg') ||
                path.endsWith('.jpeg') ||
                path.endsWith('.gif') ||
                path.endsWith('.webp')) {
              final bytes = await File.fromUri(uri).readAsBytes();
              await _uploadImage(bytes);
              uploaded = true;
              continue; // Handled this item
            }
          }
        }

        // Try raw image data
        if (canUpload && item.canProvide(Formats.png)) {
          item.getFile(Formats.png, (file) async {
            final bytes = await file.readAll();
            if (mounted) _uploadImage(bytes);
          });
          uploaded = true;
        } else if (canUpload && item.canProvide(Formats.jpeg)) {
          item.getFile(Formats.jpeg, (file) async {
            final bytes = await file.readAll();
            if (mounted) _uploadImage(bytes);
          });
          uploaded = true;
        }
      }
    }

    if (!uploaded && mounted) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data case ClipboardData(:final text?) when text.isNotEmpty) {
        final selection = widget.controller.selection;
        if (selection.isValid && selection.start >= 0) {
          final newText = widget.controller.text.replaceRange(
            selection.start,
            selection.end,
            text,
          );
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: selection.start + text.length,
            ),
          );
        } else {
          final newText = widget.controller.text + text;
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, child) {
          final sendButton = IconButton(
            icon: const Icon(Icons.send),
            onPressed: (widget.provider.isConnected && !_isUploading)
                ? widget.onSend
                : null,
          );

          final users = [
            for (final user in widget.provider.onlineUsers)
              if (user != widget.provider.configuration.nickname) user,
          ];

          final channels = [...widget.provider.channels.keys];
          final currentDmNickname = widget.provider.currentDmNickname;

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PrototypeConstrainedBox.tightFor(
                  height: true,
                  prototype: sendButton,
                  child: PopupMenuButton<_AttachmentOption>(
                    icon: const Icon(Icons.add),
                    onOpened: (widget.provider.isConnected && !_isUploading)
                        ? null
                        : () => Navigator.of(context).pop(),
                    enabled: widget.provider.isConnected && !_isUploading,
                    onSelected: (value) {
                      if (value == _AttachmentOption.uploadPhoto) {
                        final imgbbApiKey = locator<UserConfiguration>()
                            .imgbbApiKey
                            .trim();
                        if (imgbbApiKey.isEmpty) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('ImgBB API Key Required'),
                              content: const Text(
                                'To upload images, please configure your ImgBB API Key in the settings.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    const ConfigurationsRoute().push(context);
                                  },
                                  child: const Text('Go to Settings'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _pickImage();
                        }
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(
                          value: _AttachmentOption.uploadPhoto,
                          child: Text('Upload photo'),
                        ),
                      ];
                    },
                  ),
                ),
                const Gap(8.0),
                Expanded(
                  child: AutocompleteDropdown(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    triggers: [
                      TagAutocompleteTrigger(suggestions: users),
                      ChannelAutocompleteTrigger(suggestions: channels),
                      CommandAutocompleteTrigger(
                        command: 'dm',
                        suggestions: users,
                      ),
                      CommandAutocompleteTrigger(
                        command: 'whois',
                        suggestions: users,
                      ),
                    ],
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          final isEnter =
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter;

                          if (isEnter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            widget.onSend();
                            return KeyEventResult.handled;
                          }

                          if (event.logicalKey == LogicalKeyboardKey.keyV &&
                              (HardwareKeyboard.instance.isMetaPressed ||
                                  HardwareKeyboard.instance.isControlPressed)) {
                            _handleSuperClipboardPaste();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: widget.provider.isConnected && !_isUploading,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        contextMenuBuilder: (context, editableTextState) {
                          final buttonItems =
                              editableTextState.contextMenuButtonItems;
                          final pasteButton = ContextMenuButtonItem(
                            type: ContextMenuButtonType.paste,
                            onPressed: () {
                              _handleSuperClipboardPaste();
                              editableTextState.hideToolbar();
                            },
                          );
                          final index = buttonItems.indexWhere(
                            (item) => item.type == ContextMenuButtonType.paste,
                          );
                          if (index >= 0) {
                            buttonItems[index] = pasteButton;
                          } else {
                            buttonItems.add(pasteButton);
                          }
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: buttonItems,
                          );
                        },
                        decoration: InputDecoration(
                          prefixIcon: currentDmNickname == null
                              ? null
                              : _DmIndicator(
                                  user: currentDmNickname,
                                  onTap: () {
                                    widget.provider.setDmMode(null);
                                    widget.focusNode.requestFocus();
                                  },
                                ),
                          suffixIcon: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox.square(
                                    dimension: 16.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                    ),
                                  ),
                                )
                              : null,
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0.0,
                            minHeight: 0.0,
                          ),
                          isDense: context.isDesktop,
                          hintText: 'Type a message...',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(32.0),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 12.0,
                          ),
                          fillColor: Colors.black87,
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(4.0),
                sendButton,
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _DmIndicator extends StatelessWidget {
  const _DmIndicator({required this.user, required this.onTap});

  final String user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: getNicknameColor(user).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            user,
            style: TextStyle(
              color: getNicknameColor(user),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
