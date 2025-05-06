import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 1;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  File? _profileImage;
  String? _profileImageUrl;
  bool _isUploading = false;

  // Initialize Cloudinary once
  final Cloudinary _cloudinary = Cloudinary.signedConfig(
    apiKey: '879246687239675',
    apiSecret: 'AYuy0vuey-Q9s8bQsFvXBOmhhiA',
    cloudName: 'dwzwegpm4',
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await _firestore.collection('users').doc(user.uid).get();
    if (mounted) {
      setState(() {
        _nameController.text = userData['username'] ?? '';
        _aboutController.text = userData['about'] ?? '';
        _profileImageUrl = userData['profileImageUrl'];
      });
    }
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final compressedFile = File(
      '$path/img_${DateTime.now().millisecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(
      await FlutterImageCompress.compressWithFile(
            file.absolute.path,
            quality: 70,
          ) ??
          file.readAsBytesSync(),
    );
    return compressedFile;
  }

  Future<String?> _uploadToCloudinary(File image) async {
    try {
      final response = await _cloudinary.upload(
        file: image.path,
        resourceType: CloudinaryResourceType.image,
        folder: 'profile_pictures',
      );

      if (response.isSuccessful) {
        return response.secureUrl;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username is required')));
      return;
    }

    try {
      setState(() => _isUploading = true);

      final updates = {
        'username': _nameController.text.trim(),
        'about': _aboutController.text.trim(),
      };

      if (_profileImage != null) {
        final compressedImage = await _compressImage(_profileImage!);
        final imageUrl = await _uploadToCloudinary(compressedImage);
        if (imageUrl != null) {
          updates['profileImageUrl'] = imageUrl;
        }
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      if (mounted) {
        setState(() {
          _profileImageUrl = updates['profileImageUrl'] ?? _profileImageUrl;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<bool> _validateCurrentPassword(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All password fields are required')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    final isValid = await _validateCurrentPassword(
      _currentPasswordController.text.trim(),
    );
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is incorrect')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(_passwordController.text.trim());
        _currentPasswordController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${error.toString()}')));
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => const LoginScreen()),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${error.toString()}')),
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == 0 && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (ctx) => const ChatScreen()),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
          _isUploading = true;
        });

        // Immediately update profile to handle the upload
        await _updateProfile();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Define the theme variable
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary, // Use the theme variable
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child:
                          _isUploading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blueAccent,
                                ),
                              )
                              : CircleAvatar(
                                radius: 60,
                                backgroundImage:
                                    _profileImageUrl != null
                                        ? NetworkImage(_profileImageUrl!)
                                        : null,
                                child:
                                    _profileImageUrl == null
                                        ? const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        )
                                        : null,
                                // Only include onBackgroundImageError if backgroundImage is provided
                                onBackgroundImageError:
                                    _profileImageUrl != null
                                        ? (_, __) => setState(
                                          () => _profileImageUrl = null,
                                        )
                                        : null,
                              ),
                    ),
                    Positioned(
                      bottom: -5,
                      right: -5,
                      child: Material(
                        shape: const CircleBorder(),
                        color: Colors.blueAccent,
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                          ),
                          onPressed: _isUploading ? null : _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Profile Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Username (Required)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aboutController,
                decoration: const InputDecoration(
                  labelText: 'About (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _updateProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('Update Profile'),
                ),
              ),
              const Divider(height: 40, thickness: 1),
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _updatePassword,
                  icon: const Icon(Icons.update),
                  label: const Text('Update Password'),
                ),
              ),
              const Divider(height: 40, thickness: 1),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
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
