// job_notifier.dart
import 'package:flutter/material.dart';
import 'dashboard.dart'; // Import JobService from dashboard.dart
import 'models/job.dart';

class JobNotifier extends ChangeNotifier {
  final JobService _jobService = JobService();
  List<Job> _jobs = [];
  bool _isLoading = false;

  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;

  Future<void> fetchJobs({
    required DateTime startDate,
    required DateTime endDate,
    required int mechanicId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _jobs = await _jobService.getJobsForUser(
        startDate: startDate.toUtc(),
        endDate: endDate.toUtc(),
        mechanicId: mechanicId,
      );
    } catch (e) {
      print('Error in JobNotifier: $e');
      _jobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateJob({
    required int jobId,
    required String status,
    DateTime? startTime,
    DateTime? endTime,
    int? timeInMinutes,
    DateTime? pausedAt,
  }) async {
    final jobIndex = _jobs.indexWhere((job) => job.id == jobId);
    if (jobIndex != -1) {
      final updatedJob = _jobs[jobIndex].copyWith(
        status: status,
        startTime: startTime,
        endTime: endTime,
        timeInMinutes: timeInMinutes,
        pausedAt: pausedAt, // Pass the new pausedAt value
      );
      _jobs[jobIndex] = updatedJob;
      notifyListeners();
      try {
        if (status == 'In Progress' && startTime != null) {
          // Send startTime to the database when job is resumed
          await _jobService.updateJobStatus(
            jobId: jobId,
            status: status,
            startTime: startTime,
            pausedAt: pausedAt,
          );
        } else if (status == 'On Hold' && pausedAt != null) {
          // Send pausedAt to the database when job is paused
          await _jobService.updateJobStatus(
            jobId: jobId,
            status: status,
            pausedAt: pausedAt,
          );
        } else if (status == 'Completed' && endTime != null && timeInMinutes != null) {
          await _jobService.stopJob(jobId, endTime, timeInMinutes);
        }
      } catch (e) {
        print('Error updating job status: $e');
        // Handle error: maybe revert the change in the UI
      }
    }
  }

  Job? findJobById(int jobId) {
    return _jobs.firstWhere((job) => job.id == jobId);
  }
}