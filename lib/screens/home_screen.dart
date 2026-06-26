import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';
// IMPORT ASSOLUTO CORRETTO: Sostituisce l'import relativo che dava errore su Codemagic
import 'package:flolk/main.dart'; 

class FlolkBouncyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const FlolkBouncyButton({super.key, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  String? _myUsername;
  String? _myUid;
  bool _isCheckingProfile = true;
  int _currentTab = 0;

  String _selectedBackground = 'Default';
  bool _specialSendAnimation = true;
  bool _compactMode = false;

  final _usernameController = TextEditingController();
  final _searchController = TextEditingController();
  final _groupNameController = TextEditingController(); 
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMyProfile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndSetStatus(true);
    } else {
      _checkAndSetStatus(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkAndSetStatus(false);
    _usernameController.dispose();
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _checkAndSetStatus(bool online) async {
    try {
      if (_myUid != null && _myUsername != null) {
        await _firestore.collection('users').doc(_myUid).update({
          'isOnline': online,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Errore aggiornamento stato online: $e");
    }
  }

  void _loadMyProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _myUid = user.uid;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 5));
        if (doc.exists && doc.data() != null) {
          _myUsername = doc.get('username');
          _checkAndSetStatus(true);
          _autoCreateSelfChat();
        }
      } catch (e) {
        debugPrint("Errore o Timeout nel caricamento del profilo Firestore: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isCheckingProfile = false;
      });
    }
  }

  void _autoCreateSelfChat() async {
    if (_myUsername == null || _myUid == null) return;
    String selfChatId = "${_myUsername!}_${_myUsername!}";
    
    try {
      await _firestore.collection('chats').doc(selfChatId).set({
        'id': selfChatId,
        'users': [_myUsername, _myUsername],
        'uids': [_myUid, _myUid],
        'lastMessage': 'Spazio personale (Messaggi salvati)',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Errore creazione chat personale: $e");
    }
  }

  void _saveProfile() async {
    final username = _usernameController.text.trim();
    final user = _auth.currentUser;
    if (username.isEmpty || user == null) return;

    final searchName = username.toLowerCase();
    try {
      final existing = await _firestore.collection('users').where('searchName', isEqualTo: searchName).get();
      if (existing.docs.isNotEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Questo username è già preso!'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'searchName': searchName,
        'email': user.email,
        'uid': user.uid,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      setState(() {
        _myUsername = username;
        _myUid = user.uid;
      });
      _autoCreateSelfChat();
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    try {
      final result = await _firestore
          .collection('users')
          .where('searchName', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('searchName', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .get();

      setState(() {
        _searchResults = result.docs.where((doc) => doc.get('username') != _myUsername).toList();
      });
    } catch (e) {
      debugPrint("Errore ricerca utenti: $e");
    }
  }

  void _createNewGroup() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Crea Nuovo Gruppo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _groupNameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nome del gruppo...",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF818CF8), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _groupNameController.clear();
            },
            child: const Text("Annulla", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              final gName = _groupNameController.text.trim();
              if (gName.isEmpty) return;
              
              Navigator.pop(ctx);
              _groupNameController.clear();

              try {
                DocumentReference groupRef = await _firestore.collection('chats').add({
                  'isGroup': true,
                  'groupName': gName,
                  'createdBy': _myUsername,
                  'users': [_myUsername], 
                  'uids': [_myUid],
                  'lastMessage': null, 
                  'timestamp': FieldValue.serverTimestamp(),
                });

                await groupRef.collection('messages').add({
                  'text': "Sei stato aggiunto a questo gruppo",
                  'sender': "system",
                  'timestamp': FieldValue.serverTimestamp(),
                  'deleted_for': [],
                  'reactions': {},
                });
              } catch (e) {
                debugPrint("Errore creazione gruppo: $e");
              }
            },
            child: const Text("Crea", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStatuses() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Stati", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF10B981), width: 2)),
                  child: const CircleAvatar(backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person, color: Colors.white)),
                ),
                title: const Text("Il mio Stato", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Aggiungi un aggiornamento", style: TextStyle(color: Colors.grey, fontSize: 13)),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(String targetUsername, String targetUid) async {
    FocusScope.of(context).unfocus();
    String chatId;
    bool isSelf = targetUsername == _myUsername;
    
    if (isSelf) {
      chatId = "${_myUsername!}_${_myUsername!}";
    } else {
      List<String> ids = [_myUsername!, targetUsername];
      ids.sort();
      chatId = ids.join("_");
    }

    try {
      final docCheck = await _firestore.collection('chats').doc(chatId).get();
      String? initialMsg = 'Inizia a chattare...';
      if (docCheck.exists && docCheck.data()?['lastMessage'] != null) {
        initialMsg = docCheck.data()?['lastMessage'];
      }

      await _firestore.collection('chats').doc(chatId).set({
        'id': chatId,
        'users': [_myUsername, targetUsername],
        'uids': [_myUid, targetUid],
        'isGroup': false,
        'lastMessage': isSelf ? 'Spazio personale (Messaggi salvati)' : (docCheck.exists ? initialMsg : null),
        'timestamp': FieldValue.serverTimestamp(),
        'hidden_for_$_myUsername': false,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchController.clear();
          _searchResults = [];
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              targetUsername: targetUsername,
              targetUid: targetUid,
              myUsername: _myUsername!,
              currentBackground: _selectedBackground,
              specialSendAnimation: _specialSendAnimation,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore apertura chat: $e");
    }
  }

  void _togglePinChat(String chatId, bool currentPinnedStatus) async {
    await _firestore.collection('chats').doc(chatId).set({
      'pinned_for_$_myUsername': !currentPinnedStatus,
    }, SetOptions(merge: true));
  }

  void _clearChatMessages(String chatId) async {
    try {
      final messages = await _firestore.collection('chats').doc(chatId).collection('messages').get();
      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': 'Chat svuotata',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Errore svuotamento chat: $e");
    }
  }

  void _hideChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).set({
      'hidden_for_$_myUsername': true,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    if (_myUsername == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.blur_on_rounded, size: 70, color: Color(0xFF6366F1)),
                const SizedBox(height: 16),
                const Text('Crea Profilo Flolk', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('ATTIVA PROFILO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey, 
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        leading: _isSearching 
          ? null 
          : IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _searchUsers,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Cerca su Flolk...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)),
            )
          : const Text('Flolk', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: 0.5)),
        actions: [
          if (_currentTab == 0)
            FlolkBouncyButton(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  _searchResults = [];
                  _searchController.clear();
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
              ),
            ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFF1E293B),
                    child: Icon(Icons.account_circle, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("@$_myUsername", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        const Text("Online", style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.amp_stories_rounded, color: Color(0xFF6366F1)),
              title: const Text("Stati", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showStatuses();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_rounded, color: Color(0xFF6366F1)),
              title: const Text("Crea Gruppo", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _createNewGroup();
              },
            ),
            const Divider(color: Colors.white10),
          ],
        ),
      ),

      body: _isSearching 
          ? _buildSearchResults() 
          : (_currentTab == 0 ? _buildChatListSection() : _buildSettingsSection()),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(24)), color: Color(0xFF1E293B)),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          unselectedItemColor: Colors.grey,
          selectedItemColor: const Color(0xFF6366F1),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Flolk Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Opzioni'),
          ],
        ),
          ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('Nessun flolker trovato', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final userData = _searchResults[index].data() as Map<String, dynamic>;
        final bool isOnline = userData['isOnline'] ?? false;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person, color: Colors.white)),
            title: Text(userData['username'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text(isOnline ? 'Online' : 'Offline', style: TextStyle(color: isOnline ? const Color(0xFF10B981) : Colors.grey)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6366F1)),
            onTap: () => _openChat(userData['username'], userData['uid']),
          ),
        );
      },
    );
  }

  Widget _buildChatListSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('chats').where('users', arrayContains: _myUsername).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var chatDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isHidden = data['hidden_for_$_myUsername'] ?? false;
          final lastMsg = data['lastMessage'];
          return !isHidden && lastMsg != null;
        }).toList();

        chatDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final pinA = dataA['pinned_for_$_myUsername'] ?? false;
          final pinB = dataB['pinned_for_$_myUsername'] ?? false;

          if (pinA && !pinB) return -1;
          if (!pinA && pinB) return 1;

          final Timestamp? timeA = dataA['timestamp'] as Timestamp?;
          final Timestamp? timeB = dataB['timestamp'] as Timestamp?;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });

        if (chatDocs.isEmpty) {
          return const Center(child: Text('Nessuna chat attiva. Cerca qualcuno!', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatDoc = chatDocs[index];
            final chat = chatDoc.data() as Map<String, dynamic>;
            final List users = chat['users'] ?? [];
            final List uids = chat['uids'] ?? [];
            final bool isGroup = chat['isGroup'] ?? false;
            
            final isSelf = !isGroup && users.length == 2 && users[0] == _myUsername && users[1] == _myUsername;
            
            final targetUsername = isGroup 
                ? (chat['groupName'] ?? 'Gruppo')
                : (isSelf ? _myUsername! : users.firstWhere((name) => name != _myUsername, orElse: () => 'Utente'));
                
            final targetUid = isGroup 
                ? 'group_chat' 
                : (isSelf ? _myUid! : uids[users.indexOf(targetUsername)]);
                
            final isPinned = chat['pinned_for_$_myUsername'] ?? false;

            return StreamBuilder<DocumentSnapshot>(
              stream: isGroup ? const Stream.empty() : _firestore.collection('users').doc(targetUid).snapshots(),
              builder: (context, userSnapshot) {
                bool isOnline = false;
                if (!isGroup && userSnapshot.hasData && userSnapshot.data!.exists) {
                  isOnline = (userSnapshot.data!.data() as Map<String, dynamic>)['isOnline'] ?? false;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: _compactMode ? 0 : 6),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSelf ? const Color(0xFF6366F1).withOpacity(0.2) : const Color(0xFF0F172A),
                          radius: 24,
                          child: Icon(
                            isGroup 
                              ? Icons.groups_rounded 
                              : (isSelf ? Icons.bookmark_rounded : Icons.person), 
                            color: isSelf ? const Color(0xFF6366F1) : Colors.white
                          ),
                        ),
                        if (!isSelf && !isGroup)
                          Positioned(
                            bottom: 2, right: 2,
                            child: CircleAvatar(radius: 6, backgroundColor: isOnline ? const Color(0xFF10B981) : Colors.grey),
                          )
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isSelf ? 'Spazio Personale (Tu)' : targetUsername, 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                        ),
                        if (isPinned)
                          const Icon(Icons.push_pin_rounded, color: Color(0xFF6366F1), size: 16),
                      ],
                    ),
                    subtitle: Text(chat['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      color: const Color(0xFF1E293B),
                      onSelected: (value) {
                        if (value == 'pin') _togglePinChat(chatDoc.id, isPinned);
                        if (value == 'clear') _clearChatMessages(chatDoc.id);
                        if (value == 'delete') _hideChat(chatDoc.id);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(isPinned ? Icons.pin_drop_outlined : Icons.push_pin_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(isPinned ? 'Sblocca in alto' : 'Fissa in alto', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('Svuota chat', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Text('Elimina chat', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (isGroup) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chatDoc.id,
                              targetUsername: targetUsername,
                              targetUid: "group_chat",
                              myUsername: _myUsername!,
                              currentBackground: _selectedBackground,
                              specialSendAnimation: _specialSendAnimation,
                            ),
                          ),
                        );
                      } else {
                        _openChat(targetUsername, targetUid);
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('STILE E PERSONALIZZAZIONE Flolk', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBackground,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: <String>['Default', 'Cyberpunk', 'Smeraldo'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text('Sfondo: $value'));
              }).toList(),
              onChanged: (newValue) => setState(() => _selectedBackground = newValue!),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: SwitchListTile(
            title: const Text('Scorrimento Fluido iOS', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('La chat scorre uniformemente verso l\'alto all\'invio', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _specialSendAnimation,
            activeColor: const Color(0xFF6366F1),
            onChanged: (val) => setState(() => _specialSendAnimation = val),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: SwitchListTile(
            title: const Text('Interfaccia Compatta', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Ottimizza gli spaces per schermi mobile', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _compactMode,
            activeColor: const Color(0xFF6366F1),
            onChanged: (val) => setState(() => _compactMode = val),
          ),
        ),
        
        const SizedBox(height: 32),
        const Text('ACCOUNT', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Disconnetti da Flolk', style: TextStyle(color: Colors.white, fontSize: 15)),
            onTap: () async {
              _checkAndSetStatus(false);
              await _auth.signOut();
              if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthScreen()));
            },
          ),
        ),
      ],
    );
  }
}
