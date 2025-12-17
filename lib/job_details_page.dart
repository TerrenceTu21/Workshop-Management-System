// job_details_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'digital_sign_off_page.dart';
import 'notes_and_capture_page.dart';
import 'service_history_page.dart';
import 'parts_assigned_page.dart';
import 'job_notifier.dart';
import 'models/job.dart';

class JobDetailsPage extends StatefulWidget {
  final Job job;

  const JobDetailsPage({super.key, required this.job});

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _NotesAndImages {
  final int noteId;
  final String? noteText;
  final String? imageUrl;
  final DateTime timestamp;

  _NotesAndImages({
    required this.noteId,
    this.noteText,
    this.imageUrl,
    required this.timestamp,
  });

  factory _NotesAndImages.fromJson(Map<String, dynamic> json) {
    return _NotesAndImages(
      noteId: json['note_id'] as int,
      noteText: json['note_text'] as String?,
      imageUrl: json['image_url'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  Job? _currentJob;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  bool _isLoading = false;
  List<_NotesAndImages> _notesAndImages = [];
  final _supabase = Supabase.instance.client;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeJobState();
    });
  }

  void _initializeJobState() async {
    final jobNotifier = Provider.of<JobNotifier>(context, listen: false);
    _currentJob = jobNotifier.findJobById(widget.job.id!);

    if (_currentJob != null) {
      if (_currentJob!.status == 'In Progress' && _currentJob!.startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_currentJob!.startTime!);
          _isPaused = false;
        });
        _startTimer();
      } else if (_currentJob!.status == 'On Hold' && _currentJob!.startTime != null && _currentJob!.pausedAt != null) {
        setState(() {
          _elapsedTime = _currentJob!.pausedAt!.difference(_currentJob!.startTime!);
          _isPaused = true;
        });
      }
      _fetchNotesAndImages();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_currentJob!.startTime!);
        });
      }
    });
  }

  Future<void> _fetchNotesAndImages() async {
    try {
      final List<dynamic> response = await _supabase
          .from('job_notes_and_images')
          .select('*')
          .eq('job_id', widget.job.id!)
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _notesAndImages = response.map((item) => _NotesAndImages.fromJson(item)).toList();
        });
      }
    } catch (e) {
      print('Error fetching notes and images: $e');
    }
  }

  // New function to check if all parts are retrieved
  Future<bool> _areAllPartsRetrieved(int jobId) async {
    final response = await _supabase
        .from('job_parts')
        .select('status')
        .eq('job_id', jobId);

    if (response.isEmpty) return true; // If there are no parts, the condition is met.

    return response.every((part) => part['status'] == 'Retrieved');
  }

  Future<void> _startJob() async {
    if (_currentJob == null) return;

    // Check if all parts are retrieved before starting the job
    final allPartsRetrieved = await _areAllPartsRetrieved(_currentJob!.id!);

    if (!allPartsRetrieved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot start job. Not all parts have been retrieved.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final now = DateTime.now().toUtc();
      final jobNotifier = Provider.of<JobNotifier>(context, listen: false);
      await jobNotifier.updateJob(
        jobId: _currentJob!.id!,
        status: 'In Progress',
        startTime: now,
      );

      // FIX: Use Navigator.of(context).pop() to return to the previous page.
      // The pop() operation itself is what triggers the dashboard to rebuild
      // if it is listening to the JobNotifier, which it should be.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job Started!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start job: $e')),
        );
      }
    }
  }

  Future<void> _pauseJob() async {
    if (_currentJob == null) return;

    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isPaused = true;
      });
    }

    try {
      await Provider.of<JobNotifier>(context, listen: false).updateJob(
        jobId: _currentJob!.id!,
        status: 'On Hold',
        pausedAt: DateTime.now().toUtc(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job Paused.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pause job: $e')),
        );
      }
    }
  }

  Future<void> _continueJob() async {
    if (_currentJob == null) return;

    final timePaused = DateTime.now().difference(_currentJob!.pausedAt!);
    _currentJob!.startTime = _currentJob!.startTime!.add(timePaused);

    if (mounted) {
      setState(() {
        _isPaused = false;
      });
    }

    _startTimer();

    try {
      await Provider.of<JobNotifier>(context, listen: false).updateJob(
        jobId: _currentJob!.id!,
        status: 'In Progress',
        startTime: _currentJob!.startTime!.toUtc(),
        pausedAt: null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job Resumed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resume job: $e')),
        );
      }
    }
  }

  Future<void> _stopJob() async {
    if (_currentJob == null) return;
    _timer?.cancel();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DigitalSignOffPage(job: _currentJob!),
      ),
    ).then((_) {
      _initializeJobState();
    });
  }

  Future<void> _deleteNote(int noteId, String? imageUrl) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _supabase
          .from('job_notes_and_images')
          .delete()
          .eq('note_id', noteId);

      if (imageUrl != null) {
        final fileName = imageUrl.split('/').last;
        await _supabase.storage
            .from('job_images')
            .remove(['$fileName']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note and image deleted.')),
        );
      }

      await _fetchNotesAndImages();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(int noteId, String? imageUrl) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this note and image?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteNote(noteId, imageUrl);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool hasHistoryButton = false,
    bool hasPartsButton = false,
    int? vehicleId,
    String? licensePlate,
    int? jobId,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade400),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasHistoryButton || hasPartsButton) const Spacer(),
                if (hasHistoryButton)
                  ElevatedButton(
                    onPressed: () {
                      if (vehicleId != null && licensePlate != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ServiceHistoryPage(
                              vehicleId: vehicleId,
                              licensePlate: licensePlate,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('History'),
                  ),
                if (hasPartsButton && jobId != null)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PartsAssignedPage(jobId: jobId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Parts'),
                  ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notes, color: Color.fromRGBO(3, 169, 244, 1)),
                SizedBox(width: 8),
                Text(
                  'Job Notes & Images',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (_notesAndImages.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                      'No notes or images added yet.',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _notesAndImages.length,
                itemBuilder: (context, index) {
                  final note = _notesAndImages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(note.timestamp),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _showDeleteConfirmationDialog(note.noteId, note.imageUrl);
                              },
                            ),
                          ],
                        ),
                        if (note.noteText != null)
                          Text(
                            note.noteText!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        if (note.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Image.network(
                              note.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error_outline, color: Colors.red);
                              },
                            ),
                          ),
                        if (index < _notesAndImages.length - 1)
                          const Divider(height: 24),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopwatchSection() {
    String formattedTime = '';

    if (_currentJob!.status == 'Accepted') {
      formattedTime = 'Ready to Start';
    } else if (_currentJob!.status == 'In Progress' || _currentJob!.status == 'On Hold') {
      formattedTime = [
        _elapsedTime.inHours.toString().padLeft(2, '0'),
        _elapsedTime.inMinutes.remainder(60).toString().padLeft(2, '0'),
        _elapsedTime.inSeconds.remainder(60).toString().padLeft(2, '0')
      ].join(':');
    } else if (_currentJob!.status == 'Completed' && _currentJob!.timeInMinutes != null) {
      final totalMinutes = _currentJob!.timeInMinutes!;
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;

      if (hours > 0) {
        formattedTime = '${hours}h ${minutes}m';
      } else {
        formattedTime = '${minutes}m';
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, color: Colors.black54, size: 20),
                SizedBox(width: 8),
                Text(
                  'Current Task:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currentJob!.title ?? 'No Title',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Text(
              _currentJob!.status ?? '',
              style: TextStyle(
                fontSize: 14,
                color: _isPaused ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 16),
            if (_currentJob!.status == 'Accepted')
              _buildStopwatchButton(
                onPressed: _startJob,
                icon: Icons.play_arrow,
                color: Colors.green,
              )
            else if (_currentJob!.status == 'In Progress')
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStopwatchButton(
                    onPressed: _pauseJob,
                    icon: Icons.pause,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 16),
                  _buildStopwatchButton(
                    onPressed: _stopJob,
                    icon: Icons.stop,
                    color: Colors.red,
                  ),
                ],
              )
            else if (_currentJob!.status == 'On Hold')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStopwatchButton(
                      onPressed: _continueJob,
                      icon: Icons.play_arrow,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _buildStopwatchButton(
                      onPressed: _stopJob,
                      icon: Icons.stop,
                      color: Colors.red,
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopwatchButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 40),
      style: IconButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobNotifier>(
      builder: (context, jobNotifier, child) {
        final job = jobNotifier.findJobById(widget.job.id!);

        if (job == null) {
          return const Scaffold(
            body: Center(
              child: Text('Job not found or has been completed.'),
            ),
          );
        }

        _currentJob = job;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Job Details', style: TextStyle(color: Colors.black)),
            centerTitle: true,
            backgroundColor: Colors.blue.shade400,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStopwatchSection(),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Customer Information',
                  icon: Icons.person_outline,
                  children: [
                    _buildInfoRow('Name', _currentJob!.customerName),
                    _buildInfoRow('Phone', _currentJob!.customerPhone),
                    _buildInfoRow('Email', _currentJob!.customerEmail),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Vehicle Information',
                  icon: Icons.directions_car_outlined,
                  hasHistoryButton: true,
                  vehicleId: _currentJob!.vehicleId,
                  licensePlate: _currentJob!.licensePlate,
                  children: [
                    _buildInfoRow('Make', _currentJob!.vehicleMake),
                    _buildInfoRow('Model', _currentJob!.vehicleModel),
                    _buildInfoRow('License Plate', _currentJob!.licensePlate),
                    _buildInfoRow('Mileage', _currentJob!.vehicleMileage.toString()),
                    _buildInfoRow('VIN', _currentJob!.vehicleVin),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Job Description',
                  icon: Icons.description_outlined,
                  hasPartsButton: true,
                  jobId: _currentJob!.id,
                  children: [
                    Text(
                      _currentJob!.title ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Requested Service:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _currentJob!.description ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Customer Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _currentJob!.custNotes ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNotesSection(),
                const SizedBox(height: 32),
                if (_currentJob!.status != 'Completed' && _currentJob!.status != 'Accepted')
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NotesAndCapturePage(job: _currentJob!),
                              ),
                            ).then((_) {
                              _fetchNotesAndImages();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Add Notes and Image'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                else if (_currentJob!.status == 'Completed')
                  const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}