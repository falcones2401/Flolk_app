import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

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
  final _storage = FirebaseStorage.instance;
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _typingController;
  bool _isUploading = false;

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

  void _sendMessage({String? mediaType, String? mediaUrl, String? fileName}) async {
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
      'fileName': fileName,
      'deleted_for': [],
      'reactions': {}, 
    });

    String lastMsgDesc = text;
    if (mediaType == 'image') lastMsgDesc = '📷 Foto';
    if (mediaType == 'video') lastMsgDesc = '🎥 Video';
    if (mediaType == 'file') lastMsgDesc = '📁 Documento: ${fileName ?? 'File'}';

    await _firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': lastMsgDesc,
      'timestamp': now,
      'typing_${widget.myUsername}': false,
    });

    if (widget.specialSendAnimation) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
          );
        }
      });
    }
  }

  Future<void> _uploadAndSendMedia(String filePath, String type, String name) async {
    setState(() => _isUploading = true);
    try {
      String ext = filePath.split('.').last;
      String storagePath = 'chats/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      UploadTask uploadTask = _storage.ref().child(storagePath).putFile(File(filePath));
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      _sendMessage(mediaType: type, mediaUrl: downloadUrl, fileName: name);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'invio del file: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _toggleReaction(String messageId, Map currentReactions, String emoji) async {
    Map updatedReactions = Map.from(currentReactions);
    if (updatedReactions[widget.myUsername] == emoji) {
      updatedReactions.remove(widget.myUsername);
    } else {
      updatedReactions[widget.myUsername] = emoji;
    }

    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions': updatedReactions});
  }

  void _showMessageActions(String messageId, Map data, bool isMe, List deletedFor) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😥', '🙏'];
    final Map reactions = data['reactions'] ?? {};
    final String? textContent = data['text'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    final isSelected = reactions[widget.myUsername] == emoji;
                    return FlolkBouncyButton(
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleReaction(messageId, reactions, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white10, height: 20),
              if (textContent != null)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                  title: const Text('Copia testo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: textContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Testo copiato negli appunti!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                title: const Text('Dettagli messaggio', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showIdDetails(data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                title: const Text('Elimina per me', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteDialog(messageId, false, deletedFor);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Elimina per tutti', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteDialog(messageId, true, deletedFor);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteDialog(String messageId, bool deleteForEveryone, List deletedFor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Sei sicuro?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          deleteForEveryone 
            ? 'Questo messaggio verrà rimosso definitivamente per tutti i partecipanti alla chat.' 
            : 'Questo messaggio non sarà più visibile sul tuo dispositivo.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (deleteForEveryone) {
                await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).delete();
              } else {
                List updatedDeleted = List.from(deletedFor);
                if (!updatedDeleted.contains(widget.myUsername)) {
                  updatedDeleted.add(widget.myUsername);
                }
                await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).update({
                  'deleted_for': updatedDeleted,
                });
              }
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showIdDetails(Map data) {
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeStr = timestamp != null 
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp.toDate()) 
        : 'Inviando...';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Info Messaggio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mittente: @${data['sender']}', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Data Invio: $timeStr', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Tipo: ${data['mediaType'] ?? 'Testo'}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1))))
        ],
      ),
    );
  }

  void _openMediaMenu() {
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
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    _uploadAndSendMedia(picked.path, 'image', picked.name);
                  }
                },
                child: _buildMediaOption(Icons.image_rounded, 'Foto', Colors.purple),
              ),
              FlolkBouncyButton(
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
                  if (picked != null) {
                    _uploadAndSendMedia(picked.path, 'video', picked.name);
                  }
                },
                child: _buildMediaOption(Icons.videocam_rounded, 'Video', Colors.pink),
              ),
              FlolkBouncyButton(
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(type: FileType.any);
                  if (result != null && result.files.single.path != null) {
                    _uploadAndSendMedia(result.files.single.path!, 'file', result.files.single.name);
                  }
                },
                child: _buildMediaOption(Icons.insert_drive_file_rounded, 'Documento', Colors.blue),
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

  void _showTargetProfileInfo() async {
    final userDoc = await _firestore.collection('users').doc(widget.targetUid).get();
    if (!userDoc.exists || !mounted) return;
    
    final userData = userDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Info Contatto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 16),
            Text('@${userData['username']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(userData['email'] ?? 'Nessuna email', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 5, backgroundColor: (userData['isOnline'] ?? false) ? const Color(0xFF10B981) : Colors.grey),
                const SizedBox(width: 8),
                Text((userData['isOnline'] ?? false) ? 'Online ora' : 'Disconnesso', style: const TextStyle(color: Colors.white70)),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi', style: TextStyle(color: Color(0xFF6366F1))))
        ],
      ),
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
                      child: FlolkBouncyButton(
                        onTap: _showTargetProfileInfo,
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
                    ),
                  ],
                ),
              ),
            ),
            if (_isUploading)
              const LinearProgressIndicator(backgroundColor: Color(0xFF1E293B), color: Color(0xFF6366F1)),
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
                  
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final List deletedFor = data['deleted_for'] ?? [];
                    return !deletedFor.contains(widget.myUsername);
                  }).toList();

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final docId = docs[index].id;
                      final data = docs[index].data() as Map<String, dynamic>;
                      final bool isMe = data['sender'] == widget.myUsername;
                      final List deletedFor = data['deleted_for'] ?? [];
                      final Map reactions = data['reactions'] ?? {};

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutBack, 
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Opacity(opacity: value, child: child),
                                  );
                                },
                                child: GestureDetector(
                                  onLongPress: () => _showMessageActions(docId, data, isMe, deletedFor),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 18),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
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
                                        if (data['mediaType'] == 'file')
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.insert_drive_file_rounded, color: Colors.white70),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    data['fileName'] ?? 'Documento',
                                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (data['text'] != null)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: data['mediaType'] != null ? 8.0 : 0, 
                                              bottom: reationsOffsetPadding(reactions),
                                            ),
                                            child: Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (reactions.isNotEmpty)
                                Positioned(
                                  bottom: -8,
                                  right: isMe ? null : 10,
                                  left: isMe ? 10 : null,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.elasticOut,
                                    builder: (context, val, child) => Transform.scale(scale: val, child: child),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: reactions.values.toSet().map((emoji) {
                                          return Text(emoji.toString(), style: const TextStyle(fontSize: 12));
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                      onTap: _openMediaMenu,
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 4),
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

  double reationsOffsetPadding(Map reactions) {
    return reactions.isNotEmpty ? 6.0 : 0.0;
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
