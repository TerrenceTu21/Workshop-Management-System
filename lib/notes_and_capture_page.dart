// notes_and_capture_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_assignment/profile_page.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import 'job_notifier.dart'; // Import the JobNotifier
import 'models/job.dart';

class NotesAndCapturePage extends StatefulWidget {
  final Job job;

  const NotesAndCapturePage({super.key, required this.job});

  @override
  State<NotesAndCapturePage> createState() => _NotesAndCapturePageState();
}

class _NotesAndCapturePageState extends State<NotesAndCapturePage> {
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Potentially load existing notes/images if you want to show them
    // For simplicity, we'll focus on adding new ones for now.
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadImageAndSaveNote() async {
    if (_notesController.text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a note or select an image.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        final String fileName = '${widget.job.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_selectedImage!.path)}';
        final String storagePath = 'job_images/$fileName';

        final response = await _supabase.storage.from('job_images').upload(
          storagePath,
          _selectedImage!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        imageUrl = _supabase.storage.from('job_images').getPublicUrl(storagePath);

      } on StorageException catch (e) {
        print('Error uploading image: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${e.message}')),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      } catch (e) {
        print('An unexpected error occurred during image upload: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred during image upload.')),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }
    }

    // Save the note and image URL to the 'job_notes_and_images' table
    try {
      await _supabase.from('job_notes_and_images').insert({
        'job_id': widget.job.id,
        'note_text': _notesController.text.isEmpty ? null : _notesController.text,
        'image_url': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Optionally, refresh job details if notes/images need to be shown on JobDetailsPage
      // Provider.of<JobNotifier>(context, listen: false).fetchJobs(...); // You might need specific job refresh

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note and image saved successfully!')),
      );

      // Clear fields after successful save
      _notesController.clear();
      setState(() {
        _selectedImage = null;
      });

    } catch (e) {
      print('Error saving note/image to database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save note/image: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes & Photo Capture', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Job Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 16),
                    Text('Customer: ${widget.job.customerName ?? 'N/A'}'),
                    Text('Vehicle: ${widget.job.vehicleMake ?? ''} ${widget.job.vehicleModel ?? ''} (License: ${widget.job.licensePlate ?? 'N/A'})'),
                    Text('Job ID: #${widget.job.jobCode ?? widget.job.id ?? 'N/A'}'),
                    Text('Status: ${widget.job.status ?? 'N/A'}'),
                    Text('Due Date: ${widget.job.createdAt != null ? DateFormat('dd MMM yyyy').format(widget.job.createdAt!.add(const Duration(days: 7))) : 'N/A'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 16),
                      Expanded(
                        child: TextField(
                          controller: _notesController,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: 'Add your notes here...',
                            border: InputBorder.none,
                          ),
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_selectedImage != null)
                            Expanded(
                              child: Image.file(
                                _selectedImage!,
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const Spacer(), // Pushes the camera icon to the right
                          IconButton(
                            icon: const Icon(Icons.camera_alt, size: 30),
                            onPressed: _pickImage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadImageAndSaveNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Note & Image'),
              ),
            ),
            // The Digital Sign Off button has been removed from here.

            // To ensure the button and content don't overlap with a bottom navigation bar,
            // the SizedBox with height 8 is still useful if you have a bottom bar.
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}