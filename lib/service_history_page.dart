// service_history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard.dart'; // Import the Job and JobService classes
import 'models/job.dart';

class ServiceHistoryPage extends StatefulWidget {
  final int vehicleId;
  final String licensePlate;

  const ServiceHistoryPage({
    super.key,
    required this.vehicleId,
    required this.licensePlate,
  });

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  final JobService _jobService = JobService();
  late Future<List<Job>> _serviceHistoryFuture;

  @override
  void initState() {
    super.initState();
    _serviceHistoryFuture = _jobService.getServiceHistory(widget.vehicleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Service History for ${widget.licensePlate}',
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Job>>(
        future: _serviceHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return const Center(child: Text('No service history found for this vehicle.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(
                    job.title ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(job.description ?? 'No Description'),
                  trailing: Text(
                    job.createdAt != null
                        ? '${job.createdAt!.day}/${job.createdAt!.month}/${job.createdAt!.year}'
                        : 'N/A',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}