import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _typingController;
  bool _isUploading = false;
  Map<String, dynamic>? _repliedMessage;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    
    _updateReadStatus();
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

  void _updateReadStatus() {
    _firestore.collection('chats').doc(widget.chatId).update({
      'last_read_${widget.myUsername}': FieldValue.serverTimestamp(),
    });
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

    Map<String, dynamic>? replyData;
    if (_repliedMessage != null) {
      replyData = {
        'messageId': _repliedMessage!['id'],
        'sender': _repliedMessage!['sender'],
        'text': _repliedMessage!['text'],
        'mediaType': _repliedMessage!['mediaType'],
      };
    }

    // PASSO 1: Inseriamo di base 'delivered': false al momento dell'invio
    await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
      'text': text.isEmpty ? null : text,
      'sender': widget.myUsername,
      'timestamp': now,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'deleted_for': [],
      'reactions': {}, 
      'replyTo': replyData,
      'delivered': false,
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

    setState(() {
      _repliedMessage = null;
    });

    _updateReadStatus();

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

  Future<void> _uploadAndSendMedia(String filePath, String type, String name) async {
    setState(() => _isUploading = true);
    try {
      String cloudinaryUrl = "https://res.cloudinary.com/..."; 
      _sendMessage(mediaType: type, mediaUrl: cloudinaryUrl, fileName: name);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore file: $e'), backgroundColor: Colors.redAccent),
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
    await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).update({'reactions': updatedReactions});
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
                      const SnackBar(content: Text('Testo copiato!'), duration: Duration(seconds: 1)),
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
        title: const Text('Sei sicuro?', style: TextStyle(color: Colors.white)),
        content: Text(deleteForEveryone ? 'Rimuoverai il messaggio per tutti.' : 'Lo nasconderai solo a te stesso.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              if (deleteForEveryone) {
                await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).delete();
              } else {
                List updatedDeleted = List.from(deletedFor);
                if (!updatedDeleted.contains(widget.myUsername)) updatedDeleted.add(widget.myUsername);
                await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).update({'deleted_for': updatedDeleted});
              }
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showIdDetails(Map data) {
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeStr = timestamp != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp.toDate()) : 'Inviando...';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Info Messaggio', style: TextStyle(color: Colors.white)),
        content: Text('Mittente: @${data['sender']}\nData: $timeStr\nTipo: ${data['mediaType'] ?? 'Testo'}', style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _openMediaMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FlolkBouncyButton(
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) _uploadAndSendMedia(picked.path, 'image', picked.name);
              },
              child: _buildMediaOption(Icons.image_rounded, 'Foto', Colors.purple),
            ),
            FlolkBouncyButton(
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
                if (picked != null) _uploadAndSendMedia(picked.path, 'video', picked.name);
              },
              child: _buildMediaOption(Icons.videocam_rounded, 'Video', Colors.pink),
            ),
            FlolkBouncyButton(
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(type: FileType.any);
                if (result != null && result.files.single.path != null) _uploadAndSendMedia(result.files.single.path!, 'file', result.files.single.name);
              },
              child: _buildMediaOption(Icons.insert_drive_file_rounded, 'Documento', Colors.blue),
            ),
          ],
        ),
      ),
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
        title: Text('@${userData['username']}', style: const TextStyle(color: Colors.white)),
        content: Text('Status: ${(userData['isOnline'] ?? false) ? 'Online' : 'Offline'}', style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi'))],
      ),
    );
  }

  BoxDecoration _getChatBackground() {
    if (widget.currentBackground == 'Cyberpunk') {
      return const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF311042)], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    } else if (widget.currentBackground == 'Smeraldo') {
      return const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF0F172A)], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    }
    return const BoxDecoration(color: Color(0xFF0F172A));
  }

  // PASSO 3: Logica di rendering grafico delle tre tipologie di spunta
  Widget _buildStatusTicks(Map<String, dynamic> messageData, Timestamp? targetLastRead) {
    final Timestamp? msgTime = messageData['timestamp'] as Timestamp?;
    final bool isDelivered = messageData['delivered'] ?? false;

    if (msgTime == null) {
      return const Icon(Icons.access_time_rounded, size: 13, color: Colors.white60);
    }
    
    // 1. Doppia blu: Letto (L'altro utente ha aperto la chat dopo l'orario del messaggio)
    if (targetLastRead != null && targetLastRead.toDate().isAfter(msgTime.toDate())) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF38BDF8)),
        ],
      );
    }

    // 2. Doppia grigia: Consegnato (L'altro utente ha l'app attiva in background/foreground ma non ha letto)
    if (isDelivered) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, size: 14, color: Colors.white60),
        ],
      );
    }

    // 3. Singola grigia: Inviato con successo al server
    return const Icon(Icons.done_rounded, size: 14, color: Colors.white60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _getChatBackground(),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('chats').doc(widget.chatId).snapshots(),
          builder: (context, chatMetaSnapshot) {
            Timestamp? targetLastRead;
            if (chatMetaSnapshot.hasData && chatMetaSnapshot.data!.exists) {
              final chatData = chatMetaSnapshot.data!.data() as Map<String, dynamic>;
              targetLastRead = chatData['last_read_${widget.targetUsername}'] as Timestamp?;
            }

            return Column(
              children: [
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
                    child: Row(
                      children: [
                        FlolkBouncyButton(
                          onTap: () => Navigator.pop(context),
                          child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
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
                                    Text(widget.targetUsername == widget.myUsername ? '${widget.targetUsername} (Tu)' : widget.targetUsername, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                if (_isUploading) const LinearProgressIndicator(backgroundColor: Color(0xFF1E293B), color: Color(0xFF6366F1)),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      
                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final List deletedFor = data['deleted_for'] ?? [];
                        return !deletedFor.contains(widget.myUsername);
                      }).toList();

                      if (docs.isNotEmpty) {
                        _updateReadStatus();

                        // PASSO 2: Quando ricevi i messaggi inviati dall'altro utente e "delivered" è ancora false, 
                        // il tuo dispositivo notifica a Firestore che il messaggio è ufficialmente arrivato (doppia spunta grigia).
                        for (var doc in docs) {
                          final msgData = doc.data() as Map<String, dynamic>;
                          if (msgData['sender'] != widget.myUsername && (msgData['delivered'] == false || msgData['delivered'] == null)) {
                            _firestore
                                .collection('chats')
                                .doc(widget.chatId)
                                .collection('messages')
                                .doc(doc.id)
                                .update({'delivered': true});
                          }
                        }
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final docId = docs[index].id;
                          final data = docs[index].data() as Map<String, dynamic>;
                          final bool isMe = data['sender'] == widget.myUsername;
                          final List deletedFor = data['deleted_for'] ?? [];
                          final Map reactions = data['reactions'] ?? {};

                          return Dismissible(
                            key: ValueKey('dismiss_$docId'),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (_) async {
                              setState(() {
                                _repliedMessage = {
                                  'id': docId,
                                  'sender': data['sender'],
                                  'text': data['text'],
                                  'mediaType': data['mediaType'],
                                };
                              });
                              _focusNode.requestFocus();
                              return false;
                            },
                            background: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.reply_rounded, color: const Color(0xFF6366F1).withOpacity(0.6), size: 24),
                              ),
                            ),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      key: ValueKey('anim_$docId'),
                                      tween: Tween<double>(
                                        begin: isMe ? 0.85 : 1.0,
                                        end: 1.0,
                                      ),
                                      duration: Duration(milliseconds: isMe ? 200 : 0),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Transform.scale(scale: value, child: child);
                                      },
                                      child: GestureDetector(
                                        onLongPress: () => _showMessageActions(docId, data, isMe, deletedFor),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                          decoration: BoxDecoration(
                                            color: isMe ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 16),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (data['replyTo'] != null)
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 6),
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6), border: const Border(left: BorderSide(color: Color(0xFF818CF8), width: 2))),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(data['replyTo']['sender'] == widget.myUsername ? 'Tu' : '@${data['replyTo']['sender']}', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                                      Text(data['replyTo']['text'] ?? 'Media', style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    ],
                                                  ),
                                                ),
                                              if (data['mediaType'] == 'image') ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(data['mediaUrl'])),
                                              if (data['mediaType'] == 'video') const Icon(Icons.play_circle_fill, size: 40, color: Colors.white),
                                              if (data['mediaType'] == 'file') Text('📁 ${data['fileName']}', style: const TextStyle(color: Colors.white)),
                                              if (data['text'] != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 15))),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '',
                                                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    _buildStatusTicks(data, targetLastRead),
                                                  ]
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (reactions.isNotEmpty)
                                      Positioned(
                                        bottom: -6,
                                        right: isMe ? null : 8,
                                        left: isMe ? 8 : null,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: reactions.values.toSet().map((e) => Text(e.toString(), style: const TextStyle(fontSize: 11))).toList()),
                                        ),
                                      )
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
                if (_repliedMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    child: Row(
                      children: [
                        const Icon(Icons.reply_rounded, color: Color(0xFF6366F1), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Rispondi a @${_repliedMessage!['sender']}: ${_repliedMessage!['text'] ?? 'Media'}', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => setState(() => _repliedMessage = null))
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: _repliedMessage != null ? const BorderRadius.vertical(bottom: Radius.circular(28)) : BorderRadius.circular(28)),
                    child: Row(
                      children: [
                        FlolkBouncyButton(onTap: _openMediaMenu, child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.add_rounded, color: Color(0xFF6366F1), size: 24))),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Messaggio...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        FlolkBouncyButton(onTap: () => _sendMessage(), child: const CircleAvatar(backgroundColor: Color(0xFF6366F1), radius: 18, child: Icon(Icons.send_rounded, color: Colors.white, size: 14))),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 70), lowerBound: 0.0, upperBound: 0.12)..addListener(() { setState(() {}); });
    super.initState();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: Transform.scale(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
