import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/localization_helpers.dart';
import '../../../core/network/chat_socket.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat.dart';
import '../providers/chat_providers.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _sending = false;
  late final ChatPagesOpenController _chatPagesOpen;
  late final ChatSocketService _socket;
  late final ConversationMessagesController _messages;

  @override
  void initState() {
    super.initState();
    _chatPagesOpen = ref.read(chatPagesOpenProvider.notifier);
    _socket = ref.read(chatSocketProvider);
    _messages = ref.read(
      conversationMessagesProvider(widget.conversationId).notifier,
    );

    _socket.connect();
    _socket.joinConversation(widget.conversationId);
    _socket.on('connect', _onSocketConnected);
    _socket.on('message:new', _onNewMessage);
    _socket.on('message:delivered', _onDelivered);
    _socket.on('message:read', _onRead);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chatPagesOpen.increment();
      // Pull in anything sent while this screen was closed, then mark the
      // conversation read so the sender sees two blue ticks.
      _messages.refresh();
      ref.read(chatRepositoryProvider).markRead(widget.conversationId);
      ref.read(conversationsProvider.notifier).reloadSilently();
      _scrollToBottom();
    });
  }

  /// socket.io reconnects create a fresh connection with no rooms, so re-join
  /// the conversation (and catch up) whenever the link comes back up.
  void _onSocketConnected(dynamic _) {
    if (!mounted) return;
    _socket.joinConversation(widget.conversationId);
    _messages.refresh();
    ref.read(chatRepositoryProvider).markRead(widget.conversationId);
  }

  @override
  void dispose() {
    _socket.remove('connect', _onSocketConnected);
    _socket.remove('message:new', _onNewMessage);
    _socket.remove('message:delivered', _onDelivered);
    _socket.remove('message:read', _onRead);
    _socket.leaveConversation(widget.conversationId);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
    Future<void>.microtask(() {
      try {
        _chatPagesOpen.decrement();
      } catch (_) {
        // The provider was already disposed (e.g. during app teardown).
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// A conversation participant's device received/saw a message we (or the
  /// other side) sent. Applies receipts to the list and, for messages the
  /// OTHER side sent us, tells the server we have them (grey + blue ticks).
  void _onNewMessage(dynamic data) {
    if (data is! Map) return;
    final selfId = ref.read(authControllerProvider).user?.id ?? '';
    final ChatMessage message;
    try {
      message = ChatMessage.fromApi(data, selfId: selfId);
    } catch (_) {
      return;
    }
    if (message.id.isEmpty) return;

    if (message.direction == MessageDirection.incoming) {
      _socket.markMessageDelivered(widget.conversationId, message.id);
      if (mounted)
        ref.read(chatRepositoryProvider).markRead(widget.conversationId);
    }

    if (!mounted) return;
    _messages.addIncoming(message);
    _scrollToBottom();
  }

  void _onDelivered(dynamic data) {
    if (data is! Map) return;
    final id = data['messageId']?.toString();
    if (id == null) return;
    final at = tryParseDate(data['deliveredAt']);
    _messages.applyDelivered(id, at ?? DateTime.now());
  }

  void _onRead(dynamic data) {
    if (data is! Map) return;
    final at = tryParseDate(data['readAt']);
    _messages.applyRead(at ?? DateTime.now());
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _inputController.clear();
    _scrollToBottom();
    try {
      await _messages.send(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'chat.errorSend',
                namedArgs: {'error': localizeException(context, e)},
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    if (_sending) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.tr('chat.attachPhoto'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('common.gallery')),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.tr('common.takePhoto')),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, imageQuality: 80);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('common.cameraFailed', namedArgs: {'error': '${e}'}),
            ),
          ),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final url = await ref
          .read(chatRepositoryProvider)
          .uploadImage(picked.path);
      await _messages.sendMedia(
        content: context.tr('chat.photoMediaLabel'),
        type: MessageType.image,
        mediaUrl: url,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'chat.errorAttachPhoto',
                namedArgs: {'error': localizeException(context, e)},
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final convAsync = ref.watch(conversationsProvider);
    final conv =
        convAsync.value?.firstWhere(
          (c) => c.id == widget.conversationId,
          orElse: () => Conversation(id: widget.conversationId),
        ) ??
        const Conversation(id: '');

    final messagesState = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final messages = messagesState.messages;

    ref.listen(conversationMessagesProvider(widget.conversationId), (
      prev,
      next,
    ) {
      final prevLen = prev?.messages.length;
      if (next.loaded && (prevLen == null || prevLen != next.messages.length)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        titleSpacing: 0,
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 38,
                height: 38,
                child: conv.sellerLogo != null && conv.sellerLogo!.isNotEmpty
                    ? WImage(url: conv.sellerLogo, fit: BoxFit.cover)
                    : ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Text(
                            conv
                                .displayName(context)
                                .characters
                                .first
                                .toUpperCase(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Palette.gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.displayName(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    conv.online
                        ? context.tr('chat.online')
                        : context.tr('common.offline'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: conv.online
                          ? context.appColors.success
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !messagesState.loaded && !messagesState.failed
                ? const Center(child: CircularProgressIndicator())
                : messagesState.failed && messages.isEmpty
                ? WEmptyState(
                    icon: Icons.wifi_off,
                    title: context.tr('chat.messagesLoadError'),
                    subtitle: context.tr('chat.connectionHint'),
                    actionLabel: context.tr('common.retry'),
                    onAction: () => _messages.refresh(),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return _MessageBubble(
                        message: msg,
                        isOutgoing: msg.direction == MessageDirection.outgoing,
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _inputController,
            sending: _sending,
            onSend: _send,
            onAttach: _attach,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isOutgoing});

  final ChatMessage message;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isOutgoing
        ? Palette.navy
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isOutgoing ? Colors.white : theme.colorScheme.onSurface;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
            bottomRight: Radius.circular(isOutgoing ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.type == MessageType.image &&
                message.mediaUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: WImage(url: message.mediaUrl, fit: BoxFit.cover),
              ),
              const SizedBox(height: 6),
            ],
            if (message.type == MessageType.document) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: 16,
                    color: isOutgoing ? Palette.gold : Palette.goldDark,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.content.isEmpty
                          ? context.tr('chat.fileLabel')
                          : message.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOutgoing ? Palette.gold : Palette.goldDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (message.type == MessageType.product &&
                message.productTitle != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: isOutgoing ? Palette.gold : Palette.goldDark,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.productTitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOutgoing ? Palette.gold : Palette.goldDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (message.content.isNotEmpty &&
                message.type != MessageType.image &&
                message.type != MessageType.document)
              Text(
                message.type == MessageType.product
                    ? context.tr('chat.sharedProduct')
                    : message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chatTime(context, message.sentAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOutgoing
                          ? Colors.white54
                          : theme.colorScheme.outline,
                    ),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 4),
                    _MessageTicks(status: message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style delivery ticks shown on outgoing messages.
///
///  - [MessageStatus.sent]     → single grey tick
///  - [MessageStatus.delivered] → two grey ticks
///  - [MessageStatus.read]      → two blue ticks
class _MessageTicks extends StatelessWidget {
  const _MessageTicks({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final read = status == MessageStatus.read;
    final Color color = read ? Palette.infoBlueBright : Colors.white60;
    final icon = status == MessageStatus.sent ? Icons.done : Icons.done_all;
    return Icon(icon, size: 16, color: color);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: context.tr('chat.attachPhotoTooltip'),
            onPressed: onAttach,
            icon: const Icon(Icons.add_circle_outline),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: context.tr('chat.composerHint'),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Palette.gold,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Palette.navy,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Palette.navy),
              color: Palette.navy,
            ),
          ),
        ],
      ),
    );
  }
}
