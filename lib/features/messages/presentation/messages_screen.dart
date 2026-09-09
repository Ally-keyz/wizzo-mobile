import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/w_async.dart';
import '../../../core/widgets/w_image.dart';
import '../../../core/widgets/w_widgets.dart';
import '../models/chat.dart';
import '../providers/chat_providers.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _showSearch = false;
  String _query = '';
  late final ChatPagesOpenController _chatPagesOpen;

  @override
  void initState() {
    super.initState();
    _chatPagesOpen = ref.read(chatPagesOpenProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chatPagesOpen.increment();
    });
  }

  @override
  void dispose() {
    super.dispose();
    Future<void>.microtask(() {
      try {
        _chatPagesOpen.decrement();
      } catch (_) {
        // The provider was already disposed (e.g. during app teardown).
      }
    });
  }

  Future<void> _openNewChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        alignment: Alignment.bottomCenter,
        child: _NewChatSheet(onSelect: _startChatFromSheet),
      ),
    );
  }

  Future<void> _startChatFromSheet(ChatContact contact) async {
    final type = contact.isAdmin ? 'buyer_admin' : 'buyer_seller';
    try {
      final conv = await ref
          .read(chatRepositoryProvider)
          .start(contact.id, type: type);
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      if (conv.id.isNotEmpty) context.push('/conversation/${conv.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('chat.errorStart', namedArgs: {'error': '${e}'}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('nav.messages'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('chat.searchChats'),
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: Icon(_showSearch ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: context.tr('chat.newChat'),
            onPressed: _openNewChat,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: context.tr('chat.searchChatsHint'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => const _ConversationsSkeleton(),
              error: (e, _) => WEmptyState(
                icon: Icons.chat_bubble_outline,
                title: context.tr('chat.loadErrorTitle'),
                subtitle: '${e}',
                actionLabel: context.tr('common.retry'),
                onAction: () =>
                    ref.read(conversationsProvider.notifier).refresh(),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(onNewChat: _openNewChat);
                }
                final sorted = [...list]
                  ..sort((a, b) {
                    final at =
                        a.lastMessageAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bt =
                        b.lastMessageAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bt.compareTo(at);
                  });
                final filtered = _query.isEmpty
                    ? sorted
                    : sorted
                          .where(
                            (c) =>
                                c
                                    .displayName(context)
                                    .toLowerCase()
                                    .contains(_query) ||
                                (c.lastMessage ?? '').toLowerCase().contains(
                                  _query,
                                ),
                          )
                          .toList();
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(conversationsProvider.notifier).refresh(),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 160),
                            Center(
                              child: Text(
                                context.tr('chat.noSearchResults'),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return _ConversationTile(
                              conversation: c,
                              onTap: () {
                                ref.read(chatRepositoryProvider).markRead(c.id);
                                ref.invalidate(conversationsProvider);
                                context.push('/conversation/${c.id}');
                              },
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationsSkeleton extends StatelessWidget {
  const _ConversationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            WSkeleton(width: 52, height: 52, radius: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WSkeleton(width: 120, height: 14),
                  SizedBox(height: 8),
                  WSkeleton(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered WhatsApp-style "no conversations yet" state.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 42,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('chat.noChatsTitle'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('chat.noChatsBody'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(context.tr('chat.startNewChat')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 80%-height modal that lists every contact you can message.
class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet({required this.onSelect});

  /// Called after the sheet pops; the parent owns starting the chat and
  /// navigating (its context stays mounted, so navigation reliably happens).
  final ValueChanged<ChatContact> onSelect;

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  String _query = '';

  void _startChat(ChatContact contact) {
    Navigator.of(context).pop();
    widget.onSelect(contact);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(chatContactsProvider);

    final query = _query;
    final filtered = query.isEmpty
        ? null
        : (contactsAsync.value ?? const <ChatContact>[])
              .where(
                (c) =>
                    c.fullName.toLowerCase().contains(query) ||
                    c.displayName?.toLowerCase().contains(query) == true ||
                    c.role.toLowerCase().contains(query),
              )
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'New chat',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('common.close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: context.tr('chat.searchPeopleHint'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: contactsAsync.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    WSkeleton(width: 48, height: 48, radius: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WSkeleton(width: 110, height: 14),
                          SizedBox(height: 6),
                          WSkeleton(width: 70, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            error: (e, _) => WEmptyState(
              icon: Icons.cloud_off,
              title: context.tr('chat.contactsLoadError'),
              subtitle: '${e}',
              actionLabel: context.tr('common.retry'),
              onAction: () => ref.invalidate(chatContactsProvider),
            ),
            data: (contacts) {
              final visible = filtered ?? contacts;
              if (visible.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('chat.noContacts'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final c = visible[i];
                  return _ContactTile(contact: c, onTap: () => _startChat(c));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final ChatContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = contact.isAdmin
        ? context.tr('chat.roleAdmin')
        : contact.isSeller
        ? context.tr('common.seller')
        : context.tr('chat.roleBuyer');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _ContactAvatar(contact: contact),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (contact.isSeller) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 13,
                          color: Color(0xFF3B82F6),
                        ),
                      ],
                      if (contact.isAdmin) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact});

  final ChatContact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
            ? WImage(url: contact.avatarUrl, fit: BoxFit.cover)
            : ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    contact.fullName.isEmpty
                        ? '?'
                        : contact.fullName.characters.first.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Palette.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: unread
            ? context.appColors.goldSoft.withValues(alpha: 0.25)
            : null,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child:
                        conversation.sellerLogo != null &&
                            conversation.sellerLogo!.isNotEmpty
                        ? WImage(
                            url: conversation.sellerLogo,
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                conversation
                                    .displayName(context)
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Palette.gold,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                if (conversation.online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.appColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayName(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        chatTime(conversation.lastMessageAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: unread
                              ? Palette.goldDark
                              : theme.colorScheme.outline,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ??
                              (conversation.productTitle != null
                                  ? conversation.productTitle!
                                  : context.tr('chat.newConversation')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: unread
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Palette.navy,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          alignment: Alignment.center,
                          child: Text(
                            '${conversation.unreadCount}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Palette.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
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
