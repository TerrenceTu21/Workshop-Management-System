// dashboard.dart

import 'package:flutter/material.dart';

import 'models/job.dart';

import 'profile_page.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import 'dart:async';

import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'job_details_page.dart';

import 'login_page.dart';

import 'job_notifier.dart';

const String supabaseUrl = 'https://fvlbvxvktplbhcxrtynn.supabase.co/';

const String supabaseKey = 'sb_secret_L18VwNdlUS6KV4qroKkKtA_jwMgSDKE';

/// A service to interact with the 'jobs' table in Supabase.

class JobService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, int>> getJobCounts({
    required DateTime startDate,
    required DateTime endDate,
    required int mechanicId,
  }) async {
    // FIX: The query is reordered. The 'or' filter is now the first filter applied after .select().
    final response = await _supabase
        .from('jobs')
        .select('status')
        .or('and(start_time.gte.${startDate.toIso8601String()},start_time.lte.${endDate.toIso8601String()}),status.in.(In Progress,On Hold)')
        .eq('mechanic_id', mechanicId);

    final jobs = response as List<dynamic>;

    final Map<String, int> counts = {
      'Accepted': 0,
      'In Progress': 0,
      'On Hold': 0,
      'Completed': 0,
    };

    for (var job in jobs) {
      final status = job['status'];
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }

    return counts;
  }

  Future<List<Job>> getJobsForUser({
    required DateTime startDate,
    required DateTime endDate,
    required int mechanicId,
  }) async {
    try {
      final response = await _supabase
          .from('jobs')
          .select('*, customers(name, email, contact_number), vehicles(make, model, license_plate, vin_number, mileage)')
          .or('and(status.eq.Accepted,start_time.gte.${startDate.toIso8601String()},start_time.lte.${endDate.toIso8601String()}),and(status.eq.Completed,end_time.gte.${startDate.toIso8601String()},end_time.lte.${endDate.toIso8601String()})')
          .eq('mechanic_id', mechanicId)
          .order('start_time', ascending: false);


      final List<dynamic> jobsData = response;
      return jobsData.map((json) => Job.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching jobs: $e');
      return [];
    }
  }

  Future<List<Job>> getServiceHistory(int vehicleId) async {
    final response = await _supabase
        .from('jobs')
        .select(
          '*, customers(name, email, contact_number), vehicles(make, model, license_plate, vin_number, mileage)',
        )
        .eq('vehicle_id', vehicleId)
        .eq('status', 'Completed')
        .order('created_at', ascending: false);

    final List<dynamic> jobsData = response;

    return jobsData.map((json) => Job.fromJson(json)).toList();
  }

  Future<bool> areAllPartsRetrieved(int jobId) async {
    final response = await _supabase
        .from('job_parts')
        .select('status')
        .eq('job_id', jobId);

    if (response.isEmpty)
      return true; // Fix: If there are no parts, the condition is met.

    return response.every((part) => part['status'] == 'Retrieved');
  }

  Future<void> startJob(int jobId) async {
    await _supabase
        .from('jobs')
        .update({
          'status': 'In Progress',

          'start_time': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('job_id', jobId);
  }

  Future<void> stopJob(int jobId, DateTime endTime, int timeInMinutes) async {
    final updates = {
      'status': 'Completed',

      'end_time': endTime.toUtc().toIso8601String(),

      'time_in_minutes': timeInMinutes,
    };

    final response = await _supabase
        .from('jobs')
        .update(updates)
        .eq('job_id', jobId)
        .select();

    if (response.isEmpty) {
      throw Exception('Failed to stop job in the database.');
    }
  }

  Future<void> updateJobStatus({
    required int jobId,

    required String status,

    DateTime? startTime,

    DateTime? pausedAt,
  }) async {
    final updates = {'status': status};

    if (startTime != null) {
      updates['start_time'] = startTime.toIso8601String();
    }

    if (pausedAt != null) {
      updates['paused_at'] = pausedAt.toIso8601String();
    }

    final response = await _supabase
        .from('jobs')
        .update(updates)
        .eq('job_id', jobId)
        .select();

    if (response.isEmpty) {
      throw Exception('Failed to update job status in the database.');
    }
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JobService _jobService = JobService();

  String _filter = 'Today';

  int? _currentMechanicId;

  @override
  void initState() {
    super.initState();

    _loadMechanicId();
  }

  Future<void> _loadMechanicId() async {
    final prefs = await SharedPreferences.getInstance();

    final mechanicId = prefs.getInt('mechanic_id');

    if (mechanicId != null) {
      setState(() {
        _currentMechanicId = mechanicId;
      });

      Provider.of<JobNotifier>(context, listen: false).fetchJobs(
        startDate: _startDate,

        endDate: _endDate,

        mechanicId: mechanicId,
      );
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  DateTime get _startDate {
    final now = DateTime.now();

    if (_filter == 'Today') {
      return DateTime(now.year, now.month, now.day).toUtc();
    } else {
      final today = DateTime(now.year, now.month, now.day);

      return today.subtract(Duration(days: today.weekday - 1)).toUtc();
    }
  }

  DateTime get _endDate {
    final now = DateTime.now();

    if (_filter == 'Today') {
      return DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc();
    } else {
      final today = DateTime(now.year, now.month, now.day);

      final firstDayOfWeek = today.subtract(Duration(days: today.weekday - 1));

      return firstDayOfWeek
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59))
          .toUtc();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMechanicId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<JobNotifier>(
      builder: (context, jobNotifier, child) {
        final jobs = jobNotifier.jobs;

        final isLoading = jobNotifier.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Jobs', style: TextStyle(color: Colors.black)),

            backgroundColor: const Color(0xFFF0F0F0),

            elevation: 0,

            centerTitle: false,

            actions: [
              /*
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black),

                onPressed: () {},
              ),

               */

              IconButton(
                icon: const Icon(Icons.person_outline, color: Colors.black),

                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
              ),
            ],
          ),

          body: Column(
            children: [
              Container(
                color: const Color(0xFFF0F0F0),

                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),

                child: Row(
                  children: [
                    _buildFilterButton('Today', 'Today'),

                    const SizedBox(width: 8),

                    _buildFilterButton('This Week', 'This Week'),
                  ],
                ),
              ),

              _buildJobStats(),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : jobs.isEmpty
                    ? _buildNoJobsView()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),

                        itemCount: jobs.length,

                        itemBuilder: (context, index) {
                          final job = jobs[index];

                          return JobCard(job: job);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  FutureBuilder<Map<String, int>> _buildJobStats() {
    return FutureBuilder<Map<String, int>>(
      future: _jobService.getJobCounts(
        startDate: _startDate,

        endDate: _endDate,

        mechanicId: _currentMechanicId!,
      ),

      builder: (context, snapshot) {
        final counts = snapshot.data ?? {};

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              _buildStatChip('Accepted', counts['Accepted'] ?? 0, Colors.blue),

              _buildStatChip(
                'In Progress',
                counts['In Progress'] ?? 0,
                Colors.blue,
              ),

              _buildStatChip('On Hold', counts['On Hold'] ?? 0, Colors.blue),

              _buildStatChip(
                'Completed',
                counts['Completed'] ?? 0,
                Colors.blue,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _filter == value;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _filter = value;

          Provider.of<JobNotifier>(context, listen: false).fetchJobs(
            startDate: _startDate,

            endDate: _endDate,

            mechanicId: _currentMechanicId!,
          );
        });
      },

      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF5096FF)
            : const Color(0xFFE0E0E0),

        foregroundColor: isSelected ? Colors.white : Colors.black,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

        elevation: 0,

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),

      child: Text(label),
    );
  }

  Widget _buildStatChip(String title, int count, Color color) {
    return Container(
      width: 80,

      padding: const EdgeInsets.symmetric(vertical: 12.0),

      decoration: BoxDecoration(
        color: color,

        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        children: [
          Text(
            count.toString(),

            style: const TextStyle(
              fontSize: 24,

              fontWeight: FontWeight.bold,

              color: Colors.white,
            ),
          ),

          Text(
            title,

            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNoJobsView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Text(
            'No Jobs Available!',

            style: TextStyle(
              fontSize: 24,

              fontWeight: FontWeight.bold,

              color: Colors.black54,
            ),
          ),

          SizedBox(height: 16),

          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final Job job;

  final JobService _jobService = JobService();

  JobCard({super.key, required this.job});

  Future<void> _handleStartJob(BuildContext context) async {
    final allPartsRetrieved = await _jobService.areAllPartsRetrieved(job.id!);

    if (!allPartsRetrieved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start job: All parts must be retrieved first.'),

          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final jobNotifier = Provider.of<JobNotifier>(context, listen: false);

    await jobNotifier.updateJob(
      jobId: job.id!,

      status: 'In Progress',

      startTime: DateTime.now().toUtc(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            JobDetailsPage(job: jobNotifier.findJobById(job.id!)!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color cardColor;

    Color statusChipColor;

    switch (job.status) {
      case 'On Hold':
        cardColor = Colors.red.shade100;

        statusChipColor = Colors.red.shade400;

        break;

      case 'In Progress':
        cardColor = Colors.orange.shade100;

        statusChipColor = Colors.orange.shade400;

        break;

      case 'Completed':
        cardColor = Colors.green.shade100;

        statusChipColor = Colors.green.shade400;

        break;

      default:
        cardColor = Colors.white;

        statusChipColor = Colors.blue.shade400;
    }

    final displayDate = job.startTime != null
        ? DateFormat('EEE, MMM d').format(job.startTime!.toLocal())
        : 'No Start Date';

    final startTimeString = job.startTime != null
        ? DateFormat('hh:mm a').format(job.startTime!.toLocal())
        : 'N/A';

    final endTimeString = job.endTime != null
        ? DateFormat('hh:mm a').format(job.endTime!.toLocal())
        : 'N/A';

    final timeRangeString = job.startTime != null && job.endTime != null
        ? '$startTimeString - $endTimeString'
        : 'No Time Range';

    final fullDateAndTimeString = job.startTime != null
        ? '$displayDate, $timeRangeString'
        : displayDate;

    String durationText;

    if (job.status == 'Completed') {
      durationText = '${job.timeInMinutes ?? 'N/A'} mins';
    } else {
      if (job.startTime != null && job.endTime != null) {
        final duration = job.endTime!.difference(job.startTime!);

        final minutes = duration.inMinutes;

        durationText = 'Estimated time: $minutes mins';
      } else {
        durationText = 'No Duration';
      }
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => JobDetailsPage(job: job)),
        );
      },

      borderRadius: BorderRadius.circular(16),

      child: Card(
        color: cardColor,

        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),

        elevation: 0,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        child: Padding(
          padding: const EdgeInsets.all(16.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    job.title ?? 'No Title',

                    style: const TextStyle(
                      fontSize: 16.0,

                      fontWeight: FontWeight.bold,

                      color: Colors.black,
                    ),
                  ),

                  _buildStatusChip(job.status ?? 'Unknown', statusChipColor),
                ],
              ),

              const SizedBox(height: 8.0),

              Row(
                children: [
                  Text(
                    '#${job.licensePlate ?? 'N/A'}',

                    style: const TextStyle(
                      fontSize: 14.0,

                      fontWeight: FontWeight.bold,

                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Text(
                    '${job.vehicleMake ?? 'N/A'} ${job.vehicleModel ?? 'N/A'}',

                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 8.0),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        fullDateAndTimeString,

                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),

                      Text(
                        durationText,

                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  Text(
                    'Bay ${job.bayLocation ?? 'N/A'}',

                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              if (job.status == 'Accepted') ...[
                const SizedBox(height: 16.0),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,

                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleStartJob(context),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,

                          foregroundColor: Colors.black,

                          padding: const EdgeInsets.symmetric(vertical: 12),

                          side: const BorderSide(color: Colors.grey),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        child: const Text('Start Job'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),

      backgroundColor: color,

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
