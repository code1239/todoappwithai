import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _dailyReview() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Gun sonu degerlendirmesi yapiliyor...')),
    );
    try {
      final p = await ref.read(apiClientProvider).dailyReview();
      ref.invalidate(proposalsProvider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(p.hasError ? 'Hata: ${p.error}' : 'Oneri hazir.')),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openHistory() async {
    final api = ref.read(apiClientProvider);
    List<ChatSession> sessions;
    try {
      sessions = await api.chatSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('Yeni sohbet'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatProvider.notifier).newSession();
              },
            ),
            const Divider(height: 1),
            if (sessions.isEmpty)
              const ListTile(title: Text('Gecmis sohbet yok')),
            ...sessions.map(
              (s) => ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  s.preview.isEmpty ? 'Sohbet #${s.id}' : s.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(s.updatedAt),
                onTap: () {
                  Navigator.pop(ctx);
                  if (s.id != null) {
                    ref.read(chatProvider.notifier).loadSession(s.id!);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPending(List<Proposal> pending) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bekleyen oneriler',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: pending
                      .map((p) => _PendingProposalCard(proposal: p))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final pending = ref.watch(proposalsProvider).maybeWhen(
          data: (list) => list
              .where((p) => p.isPending && p.kind != 'chat' && !p.hasError)
              .toList(),
          orElse: () => const <Proposal>[],
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.nightlight_round),
            tooltip: 'Gun sonu degerlendirmesi',
            onPressed: _dailyReview,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Yeni sohbet',
            onPressed: () => ref.read(chatProvider.notifier).newSession(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Sohbet tarihcesi',
            onPressed: _openHistory,
          ),
          if (pending.isNotEmpty)
            IconButton(
              tooltip: 'Bekleyen oneriler',
              onPressed: () => _openPending(pending),
              icon: Badge(
                label: Text('${pending.length}'),
                child: const Icon(Icons.pending_actions),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _Messages(chat: chat, controller: _scroll)),
          if (chat.error != null)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                chat.error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Planin icin bir sey yaz...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: chat.sending ? null : _send,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: chat.sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  final ChatState chat;
  final ScrollController controller;
  const _Messages({required this.chat, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (chat.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.messages.isEmpty && !chat.sending) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Merhaba! Haftalik planini birlikte cikaralim.\n'
            'Ornek: "bu hafta 3 kere spor yapmam lazim"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    final extra = chat.sending ? 1 : 0;
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chat.messages.length + extra,
      itemBuilder: (context, i) {
        if (i >= chat.messages.length) {
          return const _TypingIndicator();
        }
        return _Bubble(message: chat.messages[i]);
      },
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    final changes = (message.draft['changes'] as List?) ?? const [];
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
            if (!isUser && changes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DraftCard(message: message, changeCount: changes.length),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  final ChatMessage message;
  final int changeCount;
  const _DraftCard({required this.message, required this.changeCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final proposalId = message.proposalId;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16),
              SizedBox(width: 6),
              Text(
                'Plan taslagi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$changeCount degisiklik',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (proposalId != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Onayla ve uygula'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final res =
                        await ref.read(apiClientProvider).approve(proposalId);
                    ref.invalidate(dashboardProvider);
                    ref.invalidate(weekGoalsProvider);
                    ref.invalidate(weekPlanProvider);
                    ref.invalidate(proposalsProvider);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Uygulandi: ${res['applied'] ?? 0} degisiklik',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingProposalCard extends ConsumerWidget {
  final Proposal proposal;
  const _PendingProposalCard({required this.proposal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proposal.kindLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              proposal.summary.isEmpty
                  ? '${proposal.changes.length} degisiklik onerisi'
                  : proposal.summary,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await ref.read(apiClientProvider).reject(proposal.id);
                    ref.invalidate(proposalsProvider);
                  },
                  child: const Text('Reddet'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final res =
                          await ref.read(apiClientProvider).approve(proposal.id);
                      ref.invalidate(proposalsProvider);
                      ref.invalidate(dashboardProvider);
                      ref.invalidate(weekGoalsProvider);
                      ref.invalidate(weekPlanProvider);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Uygulandi: ${res['applied'] ?? 0} degisiklik',
                          ),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: const Text('Onayla ve uygula'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
