import 'dart:io'; // Ensure this import is present
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geolocator_android/geolocator_android.dart'; // Ensure this import is present

class UserChatScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserChatScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is logged in.');
      }

      final senderData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!senderData.exists || senderData.data() == null) {
        throw Exception('Sender data not found.');
      }

      final senderUsername = senderData.data()!['username'];
      if (senderUsername == null) {
        throw Exception('Sender username is null.');
      }

      await FirebaseFirestore.instance.collection('chats').add({
        'senderId': currentUser.uid,
        'receiverId': widget.userId,
        'message': message,
        'timestamp': Timestamp.now(),
        'senderUsername': senderUsername,
        'participants': [currentUser.uid, widget.userId],
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      debugPrint('Checking location permissions...');
      await _checkAndRequestLocationPermission(); // Ensure permissions are granted

      debugPrint('Fetching current location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
        'Location fetched: ${position.latitude}, ${position.longitude}',
      );
      final locationMessage = {
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'receiverId': widget.userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': Timestamp.now(),
        'senderUsername': widget.username,
        'type': 'location',
      };

      debugPrint('Adding location message to Firestore...');
      await FirebaseFirestore.instance.collection('chats').add(locationMessage);
      debugPrint('Location message added to Firestore successfully.');
    } catch (e) {
      debugPrint('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send location: ${e.toString()}')),
      );
    }
  }

  Future<void> _sendLiveLocation() async {
    // Logic to send live location updates for 1 hour
  }

  Future<void> _sendMedia(String mediaType) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: mediaType == 'image' ? ImageSource.gallery : ImageSource.camera,
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path); // Correctly use the File class
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child('${DateTime.now().toIso8601String()}_${pickedFile.name}');
      await ref.putFile(file); // Use the file instance here
      final mediaUrl = await ref.getDownloadURL();

      final mediaMessage = {
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'receiverId': widget.userId,
        'mediaUrl': mediaUrl,
        'timestamp': Timestamp.now(),
        'senderUsername': widget.username,
        'type': mediaType,
      };
      await FirebaseFirestore.instance.collection('chats').add(mediaMessage);
    }
  }

  void _openLocation(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps?q=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.username}'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('chats')
                          .where(
                            'participants',
                            arrayContains:
                                FirebaseAuth.instance.currentUser?.uid,
                          )
                          .orderBy('timestamp', descending: false)
                          .snapshots(),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No messages yet.'));
                    }
                    final messages =
                        snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return (data['senderId'] ==
                                      FirebaseAuth.instance.currentUser?.uid &&
                                  data['receiverId'] == widget.userId) ||
                              (data['senderId'] == widget.userId &&
                                  data['receiverId'] ==
                                      FirebaseAuth.instance.currentUser?.uid);
                        }).toList();
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (ctx, index) {
                        final message = messages[index];
                        final data = message.data() as Map<String, dynamic>;
                        final timestamp =
                            (data['timestamp'] as Timestamp).toDate();
                        final formattedTime =
                            '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
                        final isSender =
                            data['senderId'] ==
                            FirebaseAuth.instance.currentUser?.uid;

                        return Align(
                          alignment:
                              isSender
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  isSender
                                      ? Colors.blue[100]
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['senderUsername'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                if (data['type'] == 'location' &&
                                    data.containsKey('latitude') &&
                                    data.containsKey('longitude'))
                                  GestureDetector(
                                    onTap:
                                        () => _openLocation(
                                          data['latitude'],
                                          data['longitude'],
                                        ),
                                    child: Text(
                                      'Location: ${data['latitude']}, ${data['longitude']}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    data['message'] ?? 'No message',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                const SizedBox(height: 5),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Type a message...',
                          border: OutlineInputBorder(), // Add outline border
                        ),
                        onTap: () {
                          _messageFocusNode.requestFocus();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                    SpeedDial(
                      animatedIcon: AnimatedIcons.menu_close,
                      backgroundColor: Colors.blue,
                      overlayColor: Colors.black,
                      overlayOpacity: 0.5,
                      children: [
                        SpeedDialChild(
                          child: const Icon(Icons.location_on),
                          label: 'Send Current Location',
                          onTap: _sendCurrentLocation,
                        ),
                        SpeedDialChild(
                          child: const Icon(Icons.share_location),
                          label: 'Send Live Location',
                          onTap: _sendLiveLocation,
                        ),
                        SpeedDialChild(
                          child: const Icon(Icons.image),
                          label: 'Send Image',
                          onTap: () => _sendMedia('image'),
                        ),
                        SpeedDialChild(
                          child: const Icon(Icons.videocam),
                          label: 'Send Video',
                          onTap: () => _sendMedia('video'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
