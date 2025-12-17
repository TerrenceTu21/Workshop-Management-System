import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'job_notifier.dart';
import 'package:intl/intl.dart';
import 'models/job.dart';


class DigitalSignOffPage extends StatefulWidget {
  final Job job;

  const DigitalSignOffPage({super.key, required this.job});

  @override
  State<DigitalSignOffPage> createState() => _DigitalSignOffPageState();
}

class _DigitalSignOffPageState extends State<DigitalSignOffPage> {
  final GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey();
  bool _isLoading = false;

  Future<void> _handleClearSignature() async {
    _signaturePadKey.currentState?.clear();
  }

  Future<void> _handleSubmitSignature() async {
    final jobNotifier = Provider.of<JobNotifier>(context, listen: false);

    // Get the signature as an image
    final renderSignature = await _signaturePadKey.currentState!.toImage(pixelRatio: 3.0);
    if (renderSignature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await renderSignature.toByteData(format: ui.ImageByteFormat.png);
      final signatureBytes = bytes!.buffer.asUint8List();

      final fileName = '${widget.job.id}_signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final storagePath = 'signatures/$fileName';

      await Supabase.instance.client.storage
          .from('job_signatures')
          .uploadBinary(
        storagePath,
        signatureBytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final signatureUrl = Supabase.instance.client.storage.from('job_signatures').getPublicUrl(storagePath);

      // Always use UTC for DB writes
      final nowUtc = DateTime.now().toUtc();
      final startUtc = widget.job.startTime?.toUtc();

// Duration calculation in UTC
      final totalMinutes = startUtc != null ? nowUtc.difference(startUtc).inMinutes : 0;

      await jobNotifier.updateJob(
        jobId: widget.job.id!,
        status: 'Completed',
        endTime: nowUtc,
        timeInMinutes: totalMinutes,
      );

      // Save the signature URL in a new column in your 'jobs' table
      await Supabase.instance.client
          .from('jobs')
          .update({'signature_url': signatureUrl})
          .eq('job_id', widget.job.id!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job successfully completed and signed off!')),
      );

      // Navigate back to the dashboard, clearing the stack
      Navigator.of(context).popUntil((route) => route.isFirst);

    } on StorageException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload signature: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Sign-Off', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Details Card
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
            const Text(
              'Signature',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Signature Pad
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SfSignaturePad(
                  key: _signaturePadKey,
                  backgroundColor: Colors.white,
                  minimumStrokeWidth: 3.0,
                  maximumStrokeWidth: 5.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleClearSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmitSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}