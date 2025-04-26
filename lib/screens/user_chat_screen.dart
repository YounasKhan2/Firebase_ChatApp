import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

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
  Timer? _liveLocationTimer;
  String? _lastLiveLocationMessageID;

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

      final senderUsername = senderData.data()!['username'];

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
      await _checkAndRequestLocationPermission();
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is logged in.');
      }

      final senderData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final senderUsername = senderData.data()!['username'];

      await FirebaseFirestore.instance.collection('chats').add({
        'senderId': currentUser.uid,
        'receiverId': widget.userId,
        'mapsUrl': googleMapsUrl,
        'timestamp': Timestamp.now(),
        'senderUsername': senderUsername,
        'type': 'location',
        'participants': [currentUser.uid, widget.userId],
      });
    } catch (e) {
      debugPrint('Error sending location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send location: ${e.toString()}')),
      );
    }
  }

  void _openLocation(String url) async {
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open location: ${e.toString()}')),
      );
    }
  }

  Future<void> _sendLiveLocation() async {
    try {
      await _checkAndRequestLocationPermission();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is logged in.');
      }

      final senderData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final senderUsername = senderData.data()!['username'];

      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final initialMessage = await _sendLocationMessage(
        initialPosition,
        senderUsername,
        isLive: true,
      );
      _lastLiveLocationMessageID = initialMessage.id;

      _liveLocationTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          if (_lastLiveLocationMessageID != null) {
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(_lastLiveLocationMessageID)
                .update({
                  'mapsUrl':
                      'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}',
                  'timestamp': Timestamp.now(),
                });
          }
        } catch (e) {
          debugPrint("Error sending live location update: $e");
        }
      });

      Future.delayed(const Duration(hours: 1), () {
        _liveLocationTimer?.cancel();
        _lastLiveLocationMessageID = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live Location Sharing Ended.')),
        );
      });
    } catch (e) {
      debugPrint('Error initiating live location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share live location: ${e.toString()}'),
        ),
      );
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _sendLocationMessage(
    Position position,
    String senderUsername, {
    bool isLive = false,
  }) async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

    return FirebaseFirestore.instance.collection('chats').add({
      'senderId': FirebaseAuth.instance.currentUser?.uid,
      'receiverId': widget.userId,
      'mapsUrl': googleMapsUrl,
      'timestamp': Timestamp.now(),
      'senderUsername': senderUsername,
      'type': isLive ? 'live_location' : 'location',
      'participants': [FirebaseAuth.instance.currentUser?.uid, widget.userId],
    });
  }

  Future<void> _sendMedia(String mediaType) async {
    final picker = ImagePicker();
    XFile? pickedFile;

    if (mediaType == 'image') {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } else if (mediaType == 'video') {
      pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child('${DateTime.now().toIso8601String()}_${pickedFile.name}');

      await ref.putFile(file);
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

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    super.dispose();
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

                        if (data['type'] == 'location' ||
                            data['type'] == 'live_location') {
                          return buildLocationMessage(data, isSender);
                        } else {
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
                                  Text(
                                    data['message'] ?? '',
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
                        }
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
                          border: OutlineInputBorder(),
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

  Widget buildLocationMessage(Map<String, dynamic> data, bool isSender) {
    return InkWell(
      onTap: () => _openLocation(data['mapsUrl']),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSender ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.2, // 70% of screen width
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['senderUsername'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              data['type'] == 'live_location' ? 'Live Location:' : 'Location:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Tap to open in Maps',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
