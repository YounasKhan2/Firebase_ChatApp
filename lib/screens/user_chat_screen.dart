// user_chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cloudinary/cloudinary.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class UserChatScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserChatScreen({Key? key, required this.userId, required this.username})
    : super(key: key);

  @override
  _UserChatScreenState createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _liveLocationTimer;
  String? _lastLiveLocationMessageID;

  final cloudinary = Cloudinary.signedConfig(
    apiKey: '879246687239675',
    apiSecret: 'AYuy0vuey-Q9s8bQsFvXBOmhhiA',
    cloudName: 'dwzwegpm4',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

    try {
      if (mediaType == 'image') {
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      } else if (mediaType == 'video') {
        pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      }

      if (pickedFile != null) {
        final file = File(pickedFile.path);

        try {
          CloudinaryResponse response;

          if (mediaType == 'image') {
            response = await cloudinary.upload(
              file: file.path,
              folder: 'chat_app/images',
              resourceType: CloudinaryResourceType.image,
            );
          } else {
            response = await cloudinary.upload(
              file: file.path,
              folder: 'chat_app/videos',
              resourceType: CloudinaryResourceType.video,
            );
          }

          if (response.isSuccessful) {
            final mediaUrl = response.secureUrl;
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) {
              throw Exception('No user is logged in.');
            }

            final senderData =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get();
            final senderUsername = senderData.data()!['username'] as String;

            final mediaMessage = {
              'senderId': currentUser.uid,
              'receiverId': widget.userId,
              'mediaUrl': mediaUrl,
              'timestamp': Timestamp.now(),
              'senderUsername': senderUsername,
              'type': mediaType,
              'participants': [currentUser.uid, widget.userId],
            };
            await FirebaseFirestore.instance
                .collection('chats')
                .add(mediaMessage);
          } else {
            print("Cloudinary upload failed: ${response.error}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Upload failed. ${response.error}")),
            );
          }
        } catch (cloudinaryError) {
          print("Cloudinary upload error: $cloudinaryError");
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Upload failed.")));
        }
      }
    } catch (e) {
      print("Error sending media: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error selecting or sending media.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.username}'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('chats')
                      .where(
                        'participants',
                        arrayContains: FirebaseAuth.instance.currentUser?.uid,
                      )
                      .orderBy('timestamp')
                      .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['participants'].contains(widget.userId);
                    }).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (ctx, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp).toDate();
                    final formattedTime =
                        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
                    final isSender =
                        data['senderId'] ==
                        FirebaseAuth.instance.currentUser?.uid;

                    if (data['type'] == 'image') {
                      return buildImageMessage(data['mediaUrl'], isSender);
                    } else if (data['type'] == 'video') {
                      return buildVideoMessage(data['mediaUrl'], isSender);
                    } else if (data['type'] == 'location' ||
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
                                isSender ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isSender)
                                Text(
                                  data['senderUsername'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              if (!isSender) const SizedBox(height: 5),
                              Text(
                                data['message'] ?? '',
                                style: const TextStyle(fontSize: 16),
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
    );
  }

  Widget buildImageMessage(String mediaUrl, bool isSender) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Image.network(mediaUrl),
      ),
    );
  }

  Widget buildVideoMessage(String videoUrl, bool isSender) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: VideoMessage(videoUrl: videoUrl, isSender: isSender),
    );
  }

  Widget buildLocationMessage(Map<String, dynamic> data, bool isSender) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSender ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(maxWidth: 250), // Limit width
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Adjust height dynamically
          children: [
            if (!isSender)
              Text(
                data['senderUsername'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (!isSender) const SizedBox(height: 5),
            Text(
              data['type'] == 'live_location' ? 'Live Location' : 'Location',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 5),
            InkWell(
              onTap: () => _openLocation(data['mapsUrl']),
              child: const Text(
                'Tap to open in Maps',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoMessage extends StatefulWidget {
  final String videoUrl;
  final bool isSender;

  const VideoMessage({Key? key, required this.videoUrl, required this.isSender})
    : super(key: key);

  @override
  _VideoMessageState createState() => _VideoMessageState();
}

class _VideoMessageState extends State<VideoMessage> {
  bool _isDownloading = false;
  String _downloadProgress = "";
  String? _downloadedFilePath;

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        widget.videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            setState(() {
              _downloadProgress = '$progress%';
            });
          }
        },
      );

      setState(() {
        _downloadedFilePath = filePath;
        _isDownloading = false;
      });

      final VideoPlayerController controller = VideoPlayerController.file(
        File(filePath),
      );
      await controller.initialize();
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      print('Error downloading video: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to download video')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_downloadedFilePath != null) {
      return _buildVideoPlayer(File(_downloadedFilePath!));
    } else {
      return _buildDownloadButton();
    }
  }

  Widget _buildVideoPlayer(File videoFile) {
    return VideoPlayerWidget(videoFile: videoFile, isSender: widget.isSender);
  }

  Widget _buildDownloadButton() {
    return Align(
      alignment: widget.isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: ElevatedButton(
          onPressed: _isDownloading ? null : _downloadVideo,
          child:
              _isDownloading
                  ? Text(_downloadProgress)
                  : const Text('Download Video'),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  final bool isSender;

  const VideoPlayerWidget({
    Key? key,
    required this.videoFile,
    required this.isSender,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
      });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Align(
      alignment: widget.isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            IconButton(
              onPressed: () {
                setState(() {
                  _isPlaying ? _controller.pause() : _controller.play();
                });
              },
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
