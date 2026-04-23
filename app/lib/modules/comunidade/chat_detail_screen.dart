import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_handler.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/community_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  const ChatDetailScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  XFile? _attached;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(communityServiceProvider)
          .getMessages(widget.peerId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _markOwnUnreadAsRead();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _markOwnUnreadAsRead() async {
    final userId = SupabaseConfig.auth.currentUser!.id;
    for (final m in _messages) {
      if (m.receiverId == userId && m.readAt == null) {
        await ref.read(communityServiceProvider).markAsRead(m.id);
      }
    }
  }

  void _subscribe() {
    final userId = SupabaseConfig.auth.currentUser!.id;
    _channel = SupabaseConfig.client
        .channel('chat:$userId:${widget.peerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            final row = payload.newRecord;
            final sender = row['sender_id'] as String;
            final receiver = row['receiver_id'] as String;
            // Só interessam msgs dessa conversa
            final isThisConversation =
                (sender == userId && receiver == widget.peerId) ||
                    (sender == widget.peerId && receiver == userId);
            if (!isThisConversation) return;
            final msg = ChatMessage.fromJson(row);
            if (!mounted) return;
            setState(() => _messages = [..._messages, msg]);
            if (msg.receiverId == userId) {
              ref.read(communityServiceProvider).markAsRead(msg.id);
            }
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (img != null) setState(() => _attached = img);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _attached == null) return;
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_attached != null) {
        final bytes = kIsWeb ? await _attached!.readAsBytes() : null;
        imageUrl = await ref.read(communityServiceProvider).uploadChatPhoto(
              filename: _attached!.name,
              bytes: bytes,
              file: kIsWeb ? null : File(_attached!.path),
            );
      }
      await ref.read(communityServiceProvider).sendMessage(
            widget.peerId,
            text,
            imageUrl: imageUrl,
          );
      _ctrl.clear();
      setState(() => _attached = null);
      // _subscribe vai receber o INSERT e adicionar à lista
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: FavoColors.primaryContainer.withAlpha(40),
              backgroundImage: widget.peerAvatar != null
                  ? NetworkImage(widget.peerAvatar!)
                  : null,
              child: widget.peerAvatar == null
                  ? Text(
                      widget.peerName.isNotEmpty
                          ? widget.peerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 13,
                          color: FavoColors.primary,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.peerName,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Mande a primeira mensagem.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final isMine =
                              m.senderId == SupabaseConfig.auth.currentUser!.id;
                          return _MessageBubble(message: m, isMine: isMine);
                        },
                      ),
          ),
          if (_attached != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: _attached!.readAsBytes(),
                            builder: (_, snap) {
                              if (!snap.hasData) {
                                return const SizedBox(width: 60, height: 60);
                              }
                              return Image.memory(snap.data!,
                                  width: 60, height: 60, fit: BoxFit.cover);
                            },
                          )
                        : Image.file(File(_attached!.path),
                            width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _attached = null),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: FavoColors.surface,
              border: Border(
                  top: BorderSide(color: FavoColors.outlineVariant, width: 0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined,
                      color: FavoColors.onSurfaceVariant),
                  onPressed: _sending ? null : _pick,
                  tooltip: 'Enviar foto',
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Mensagem...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: FavoColors.primary),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isMine ? FavoColors.primary : FavoColors.surfaceContainerLow,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft:
                    isMine ? const Radius.circular(18) : const Radius.circular(4),
                bottomRight:
                    isMine ? const Radius.circular(4) : const Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.imageUrl!,
                      width: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 240,
                        height: 160,
                        color: Colors.black.withAlpha(20),
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 240,
                          height: 160,
                          color: Colors.black.withAlpha(20),
                          child: const Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    ),
                  ),
                  if (message.content.isNotEmpty) const SizedBox(height: 6),
                ],
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: TextStyle(
                        color: isMine ? Colors.white : FavoColors.onSurface),
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? Colors.white.withAlpha(180)
                        : FavoColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
