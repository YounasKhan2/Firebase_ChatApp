//chat_screen.dart
// This file defines the ChatScreen widget, which displays a list of users available for chat in the application.
// It includes a bottom navigation bar for navigating to the settings screen and a list of users fetched from Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'user_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static const routeName = '/chat';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 0;
  String _searchQuery = ''; // Search query for filtering users

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users =
                    snapshot.data!.docs
                        .where((user) => user.id != currentUser?.uid)
                        .where((user) {
                          final userData = user.data() as Map<String, dynamic>;
                          final username =
                              userData['username']?.toLowerCase() ?? '';
                          return username.contains(_searchQuery);
                        })
                        .toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  itemCount: users.length,
                  separatorBuilder:
                      (ctx, index) =>
                          const Divider(thickness: 1, color: Colors.grey),
                  itemBuilder: (ctx, index) {
                    final user = users[index];
                    final userData = user.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.blue[100],
                        backgroundImage:
                            userData.containsKey('profileImageUrl') &&
                                    userData['profileImageUrl'] != null &&
                                    userData['profileImageUrl'].isNotEmpty
                                ? NetworkImage(userData['profileImageUrl'])
                                : null,
                        child:
                            !userData.containsKey('profileImageUrl') ||
                                    userData['profileImageUrl'] == null ||
                                    userData['profileImageUrl'].isEmpty
                                ? Text(
                                  userData['username'][0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                : null,
                      ),
                      title: Text(
                        userData['username'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        userData['email'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: const Icon(
                        Icons.chat,
                        color: Colors.blueAccent,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (ctx) => UserChatScreen(
                                  userId: user.id,
                                  username: userData['username'],
                                ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
