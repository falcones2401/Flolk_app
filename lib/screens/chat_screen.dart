import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String targetUsername;
  final String targetUid;
  final String myUsername;
  final String currentBackground;
  final bool specialSendAnimation;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.targetUsername,
    required this.targetUid,
    required this.myUsername,
    required this.currentBackground,
    required this.specialSendAnimation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isTyping = _messageController.text.isNotEmpty;
    _firestore.collection('chats').doc(widget.chatId).update({
      'typing_${widget.myUsername}': isTyping,
    });
  }

  void _sendMessage({String? mediaType, String? mediaUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && mediaType == null) return;

    _messageController.clear();
    _focusNode.requestFocus();

    final now = FieldValue.serverTimestamp();

    await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
      'text': text.isEmpty ? null : text,
      'sender': widget.myUsername,
      'timestamp': now,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
    });

    await _firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': mediaType != null ? '📷 [Contenuto Multimediale]' : text,
      'timestamp': now,
      'typing_${widget.myUsername}': false,
    });

    if (widget.specialSendAnimation) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _simulateMediaUpload() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FlolkBouncyButton(
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage(mediaType: 'image', mediaUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe');
                },
                child: _buildMediaOption(Icons.image_rounded, 'Foto', Colors.purple),
              ),
              FlolkBouncyButton(
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage(mediaType: 'video', mediaUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');
                },
                child: _buildMediaOption(Icons.videocam_rounded, 'Video', Colors.pink),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  BoxDecoration _getChatBackground() {
    if (widget.currentBackground == 'Cyberpunk') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF311042)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (widget.currentBackground == 'Smeraldo') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    }
    return const BoxDecoration(color: Color(0xFF0F172A));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _getChatBackground(),
        child: Column(
          children: [
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    FlolkBouncyButton(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                      ),
                    ),
                    const CircleAvatar(backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('users').doc(widget.targetUid).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) return Text(widget.targetUsername, style: const TextStyle(color: Colors.white));
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          final bool isOnline = data['isOnline'] ?? false;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.targetUsername == widget.myUsername ? '${widget.targetUsername} (Tu)' : widget.targetUsername,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(isOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, color: isOnline ? const Color(0xFF10B981) : Colors.grey)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final bool isMe = data['sender'] == widget.myUsername;

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.linearToEaseOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['mediaType'] == 'image')
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(data['mediaUrl'], fit: BoxFit.cover),
                                  ),
                                if (data['mediaType'] == 'video')
                                  Container(
                                    height: 150,
                                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                                    child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 50, color: Colors.white)),
                                  ),
                                if (data['text'] != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: data['mediaType'] != null ? 8.0 : 0),
                                    child: Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('chats').doc(widget.chatId).snapshots(),
              builder: (context, chatSnapshot) {
                bool isTyping = false;
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                  isTyping = chatData['typing_${widget.targetUsername}'] ?? false;
                }

                if (!isTyping || widget.targetUsername == widget.myUsername) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Text('sta scrivendo ', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                      Row(
                        children: List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _typingController,
                            builder: (context, child) {
                              final delay = index * 0.2;
                              final animValue = (sin((_typingController.value * 2 * pi) + delay) + 1) / 2;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3 + (animValue * 0.7)),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          );
                        }),
                      )
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    FlolkBouncyButton(
                      onTap: _simulateMediaUpload,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.add_rounded, color: Color(0xFF6366F1), size: 26),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Messaggio...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    FlolkBouncyButton(
                      onTap: () => _sendMessage(),
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFF6366F1),
                        radius: 20,
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlolkBouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const FlolkBouncyButton({super.key, required this.child, required this.onTap});

  @override
  State<FlolkBouncyButton> createState() => _FlolkBouncyButtonState();
}

class _FlolkBouncyButtonState extends State<FlolkBouncyButton> with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      lowerBound: 0.0,
      upperBound: 0.15,
    )..addListener(() {
        setState(() {});
      });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: Transform.scale(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
