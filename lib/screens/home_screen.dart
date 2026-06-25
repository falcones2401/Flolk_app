import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';

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
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

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
    super.dispose();
  }

  void _checkAndSetStatus(bool online) async {
    if (_myUid != null && _myUsername != null) {
      await _firestore.collection('users').doc(_myUid).update({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  void _loadMyProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _myUid = user.uid;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        _myUsername = doc.get('username');
        _checkAndSetStatus(true);
        _autoCreateSelfChat();
      }
    }
    setState(() {
      _isCheckingProfile = false;
    });
  }

  void _autoCreateSelfChat() async {
    if (_myUsername == null || _myUid == null) return;
    String selfChatId = "${_myUsername!}_${_myUsername!}";
    
    await _firestore.collection('chats').doc(selfChatId).set({
      'id': selfChatId,
      'users': [_myUsername, _myUsername],
      'uids': [_myUid, _myUid],
      'lastMessage': 'Spazio personale (Messaggi salvati)',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _saveProfile() async {
    final username = _usernameController.text.trim();
    final user = _auth.currentUser;
    if (username.isEmpty || user == null) return;

    final searchName = username.toLowerCase();
    final existing = await _firestore.collection('users').where('searchName', isEqualTo: searchName).get();
    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    final result = await _firestore
        .collection('users')
        .where('searchName', isGreaterThanOrEqualTo: lowercaseQuery)
        .where('searchName', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
        .get();

    setState(() {
      _searchResults = result.docs.where((doc) => doc.get('username') != _myUsername).toList();
    });
  }

  void _openChat(String targetUsername, String targetUid) async {
    FocusScope.of(context).unfocus();
    String chatId;
    if (targetUsername == _myUsername) {
      chatId = "${_myUsername!}_${_myUsername!}";
    } else {
      List<String> ids = [_myUsername!, targetUsername];
      ids.sort();
      chatId = ids.join("_");
    }

    await _firestore.collection('chats').doc(chatId).set({
      'id': chatId,
      'users': [_myUsername, targetUsername],
      'uids': [_myUid, targetUid],
      'lastMessage': 'Inizia a chattare...',
      'timestamp': FieldValue.serverTimestamp(),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
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
        final chats = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final List users = chat['users'] ?? [];
            final List uids = chat['uids'] ?? [];
            
            final isSelf = users.length == 2 && users[0] == _myUsername && users[1] == _myUsername;
            final targetUsername = isSelf ? _myUsername! : users.firstWhere((name) => name != _myUsername, orElse: () => 'Utente');
            final targetUid = isSelf ? _myUid! : uids[users.indexOf(targetUsername)];

            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(targetUid).snapshots(),
              builder: (context, userSnapshot) {
                bool isOnline = false;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
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
                          child: Icon(isSelf ? Icons.bookmark_rounded : Icons.person, color: isSelf ? const Color(0xFF6366F1) : Colors.white),
                        ),
                        if (!isSelf)
                          Positioned(
                            bottom: 2, right: 2,
                            child: CircleAvatar(radius: 6, backgroundColor: isOnline ? const Color(0xFF10B981) : Colors.grey),
                          )
                      ],
                    ),
                    title: Text(isSelf ? 'Spazio Personale (Tu)' : targetUsername, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(chat['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                    onTap: () => _openChat(targetUsername, targetUid),
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
            subtitle: const Text('Ottimizza gli spazi per schermi mobile', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
