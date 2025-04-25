class MediaMessage {
  final String senderId;
  final String receiverId;
  final String mediaUrl;
  final DateTime timestamp;
  final String senderUsername;
  final String mediaType;

  MediaMessage({
    required this.senderId,
    required this.receiverId,
    required this.mediaUrl,
    required this.timestamp,
    required this.senderUsername,
    required this.mediaType,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp.toIso8601String(),
      'senderUsername': senderUsername,
      'mediaType': mediaType,
    };
  }
}
