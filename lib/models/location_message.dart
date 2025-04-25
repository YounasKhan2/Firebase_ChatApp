class LocationMessage {
  final String senderId;
  final String receiverId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String senderUsername;

  LocationMessage({
    required this.senderId,
    required this.receiverId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.senderUsername,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'senderUsername': senderUsername,
    };
  }
}
