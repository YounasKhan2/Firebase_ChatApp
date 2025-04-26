//chat_screen.dart
// This file defines the ChatScreen widget, which displays a list of users available for chat in the application.
// It includes a bottom navigation bar for navigating to the settings screen and a list of users fetched from Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'user_chat_screen.dart'; // Import the new user chat screen

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static const routeName = '/chat';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 0;

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
        backgroundColor: Colors.blueAccent, // Add color to the AppBar
        elevation: 4, // Add shadow for a professional look
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users =
              snapshot.data!.docs
                  .where((user) => user.id != currentUser?.uid)
                  .toList();
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder:
                (ctx, index) => const Divider(
                  thickness: 1,
                  color: Colors.grey, // Add a subtle divider color
                ),
            itemBuilder: (ctx, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    user['username'][0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  user['username'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  user['email'],
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(Icons.chat, color: Colors.blueAccent),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (ctx) => UserChatScreen(
                            userId: user.id,
                            username: user['username'],
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
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
        selectedItemColor: Colors.blueAccent, // Highlight selected item
        unselectedItemColor: Colors.grey, // Dim unselected items
      ),
    );
  }
}
