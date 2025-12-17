import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'change_password_page.dart';
import 'login_page.dart';

// Removed the global variable, as it's not needed.

class MechanicProfile {
  final int id;
  final String name;
  final String? username;
  final String email;
  final String? contactNumber;
  final String? address;
  final String? icNumber;
  final String? profilePictureUrl;

  MechanicProfile({
    required this.id,
    required this.name,
    this.username,
    required this.email,
    this.contactNumber,
    this.address,
    this.icNumber,
    this.profilePictureUrl,
  });

  factory MechanicProfile.fromJson(Map<String, dynamic> json) {
    return MechanicProfile(
      id: json['mechanic_id'] as int,
      name: json['name'] as String,
      username: json['username'] as String?,
      email: json['email'] as String,
      contactNumber: json['contact_number'] as String?,
      address: json['address'] as String?,
      icNumber: json['ic_number'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }
}

class ProfileService {
  final _supabase = Supabase.instance.client;

  Future<MechanicProfile> getMechanicProfile(String userId) async {
    final response = await _supabase
        .from('mechanics')
        .select('*')
        .eq('user_id', userId)
        .single();
    return MechanicProfile.fromJson(response);
  }

  // New method to update the mechanic's profile
  Future<void> updateMechanicProfile({
    required int mechanicId,
    String? contactNumber,
    String? address,
  }) async {
    final updates = {
      if (contactNumber != null) 'contact_number': contactNumber,
      if (address != null) 'address': address,
    };

    if (updates.isEmpty) {
      return;
    }

    await _supabase
        .from('mechanics')
        .update(updates)
        .eq('mechanic_id', mechanicId);
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  late Future<MechanicProfile> _profileFuture;

  String? _currentUserId;
  int? _currentMechanicId;

  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
        _profileFuture = _profileService.getMechanicProfile(_currentUserId!).then((profile) {
          _currentMechanicId = profile.id;
          _profileImageUrl = profile.profilePictureUrl;
          return profile;
        });
      });
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not found.')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final imageFile = await picker.pickImage(source: ImageSource.gallery);

      if (imageFile == null) {
        return;
      }

      final fileBytes = await imageFile.readAsBytes();
      final fileExtension = p.extension(imageFile.path).toLowerCase();

      final fileName = '$_currentUserId$fileExtension';
      final filePath = 'avatars/$fileName';

      await Supabase.instance.client.storage
          .from('profile-pictures')
          .uploadBinary(
        filePath,
        fileBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final publicUrl = Supabase.instance.client.storage
          .from('profile-pictures')
          .getPublicUrl(filePath);

      await Supabase.instance.client
          .from('mechanics')
          .update({'profile_picture_url': publicUrl})
          .eq('user_id', _currentUserId!);

      setState(() {
        _profileImageUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully!')),
      );

    } on StorageException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mechanic_id');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        centerTitle: false,
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<MechanicProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No profile data found.'));
          }

          final profile = snapshot.data!;
          final firstName = profile.name.split(' ').first;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Hi, $firstName',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _uploadProfileImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.blueGrey,
                          )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildProfileInfoCard(Icons.person_outline, profile.name, 'Name'),
                _buildProfileInfoCard(Icons.email_outlined, profile.email, 'Email'),
                _buildProfileInfoCard(
                    Icons.phone_outlined, profile.contactNumber ?? 'N/A', 'Phone'),
                _buildProfileInfoCard(
                    Icons.location_on_outlined, profile.address ?? 'N/A', 'Address'),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updatedProfile = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(profile: profile),
                        ),
                      );
                      if (updatedProfile != null) {
                        // Refresh the UI with the new data
                        setState(() {
                          _profileFuture = Future.value(updatedProfile);
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Change Password'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfoCard(IconData icon, String value, String label) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade400),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New EditProfilePage for editing contact number and address
class EditProfilePage extends StatefulWidget {
  final MechanicProfile profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contactController;
  late TextEditingController _addressController;

  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _contactController = TextEditingController(text: widget.profile.contactNumber);
    _addressController = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _profileService.updateMechanicProfile(
          mechanicId: widget.profile.id,
          contactNumber: _contactController.text,
          address: _addressController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Create an updated profile object to return
        final updatedProfile = MechanicProfile(
          id: widget.profile.id,
          name: widget.profile.name,
          email: widget.profile.email,
          contactNumber: _contactController.text,
          address: _addressController.text,
          icNumber: widget.profile.icNumber,
          profilePictureUrl: widget.profile.profilePictureUrl,
        );
        Navigator.of(context).pop(updatedProfile);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'User Profile - Edit',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Hi , ${widget.profile.name.split(' ').first}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.profile.profilePictureUrl != null
                        ? NetworkImage(widget.profile.profilePictureUrl!) as ImageProvider
                        : null,
                    child: widget.profile.profilePictureUrl == null
                        ? const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.blueGrey,
                    )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Edit Profile',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildEditableCard(
                    'Contact Number',
                    _contactController,
                    Icons.phone,
                    TextInputType.phone,
                        (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a contact number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildEditableCard(
                    'Address',
                    _addressController,
                    Icons.location_on,
                    TextInputType.streetAddress,
                        (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an address';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCard(
      String label,
      TextEditingController controller,
      IconData icon,
      TextInputType keyboardType,
      String? Function(String?) validator) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade400),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: InputBorder.none,
                ),
                keyboardType: keyboardType,
                validator: validator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}