// parts_assigned_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// Create a new data model for the parts assigned to a job
class JobPart {
  final int partId;
  final int jobId;
  final int quantity;
  String status; // Make status a mutable variable
  final String partNumber;
  final String partName;
  int stockLevel; // Make stock level a mutable variable

  JobPart({
    required this.partId,
    required this.jobId,
    required this.quantity,
    required this.status,
    required this.partNumber,
    required this.partName,
    required this.stockLevel,
  });

  factory JobPart.fromJson(Map<String, dynamic> json) {
    // Safely extract data from joined tables
    final dynamic partData = (json['parts'] is List) ? (json['parts'] as List).firstOrNull : json['parts'];

    return JobPart(
      partId: json['part_id'] as int,
      jobId: json['job_id'] as int,
      quantity: json['quantity'] as int,
      status: json['status'] as String,
      partNumber: partData?['part_number'] as String,
      partName: partData?['name'] as String,
      stockLevel: partData?['stock_level'] as int,
    );
  }
}

// Create a service to fetch the data for the page
class JobPartsService {
  final _supabase = Supabase.instance.client;

  Future<List<JobPart>> getAssignedParts(int jobId) async {
    final response = await _supabase
        .from('job_parts')
        .select('*, parts(name, stock_level, part_number)')
        .eq('job_id', jobId);

    final List<dynamic> partsData = response;
    return partsData.map((json) => JobPart.fromJson(json)).toList();
  }

  // Method to update the status of a specific part
  Future<void> updatePartStatus({
    required int jobId,
    required int partId,
    required String status,
  }) async {
    await _supabase
        .from('job_parts')
        .update({'status': status})
        .eq('job_id', jobId)
        .eq('part_id', partId);
  }

  // New method to deduct the stock level of a part
  Future<void> updateStockLevel({
    required int partId,
    required int quantity,
  }) async {
    // Fetch the current stock level
    final response = await _supabase
        .from('parts')
        .select('stock_level')
        .eq('part_id', partId)
        .single();

    final currentStock = response['stock_level'] as int;
    final newStockLevel = currentStock - quantity;

    // Update the stock level
    await _supabase
        .from('parts')
        .update({'stock_level': newStockLevel})
        .eq('part_id', partId);
  }
}

class PartsAssignedPage extends StatefulWidget {
  final int jobId;

  const PartsAssignedPage({super.key, required this.jobId});

  @override
  State<PartsAssignedPage> createState() => _PartsAssignedPageState();
}

class _PartsAssignedPageState extends State<PartsAssignedPage> {
  final JobPartsService _jobPartsService = JobPartsService();
  late Future<List<JobPart>> _partsFuture;

  // Use a nullable list to hold the fetched parts
  List<JobPart>? _parts;

  @override
  void initState() {
    super.initState();
    _fetchParts();
  }

  // New method to fetch parts and update the state
  Future<void> _fetchParts() async {
    try {
      final fetchedParts = await _jobPartsService.getAssignedParts(widget.jobId);
      setState(() {
        _parts = fetchedParts;
      });
    } catch (e) {
      // Handle error, e.g., show a snackbar or an error message
      print('Error fetching parts: $e');
    }
  }

  // Method to handle the part status update and stock deduction
  Future<void> _handlePartStatusUpdate(int index) async {
    final part = _parts![index];
    try {
      // Check if there is enough stock before proceeding
      if (part.stockLevel < part.quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot retrieve part. Not enough stock.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update the status of the part to 'Retrieved'
      await _jobPartsService.updatePartStatus(
        jobId: part.jobId,
        partId: part.partId,
        status: 'Retrieved',
      );

      // Deduct the stock level of the part
      await _jobPartsService.updateStockLevel(
        partId: part.partId,
        quantity: part.quantity,
      );

      // Update the local state to reflect the changes
      setState(() {
        _parts![index].status = 'Retrieved';
        _parts![index].stockLevel -= part.quantity; // Deduct locally for immediate UI update
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${part.partName} status updated to Retrieved and stock deducted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status or stock: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parts Assigned', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade400,
        foregroundColor: Colors.white,
      ),
      body: _parts == null
          ? const Center(child: CircularProgressIndicator())
          : _parts!.isEmpty
          ? const Center(child: Text('No parts assigned to this job.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _parts!.length,
        itemBuilder: (context, index) {
          final part = _parts![index];
          final isStockEnough = part.stockLevel >= part.quantity;

          // Determine the status text, colors, and trailing widget based on logic
          String statusText;
          Color statusColor;
          Color cardColor;
          Widget? trailingWidget;

          if (!isStockEnough && part.status != 'Retrieved') {
            statusText = 'Out of Stock';
            statusColor = Colors.red;
            cardColor = Colors.red.shade50;
            trailingWidget = null;
          } else if (part.status == 'Retrieved') {
            statusText = 'Retrieved';
            statusColor = Colors.green;
            cardColor = Colors.green.shade50;
            trailingWidget = const Icon(Icons.check_circle, color: Colors.green);
          } else {
            statusText = 'Pending';
            statusColor = Colors.orange;
            cardColor = Colors.orange.shade50;
            trailingWidget = IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              onPressed: () => _handlePartStatusUpdate(index),
            );
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            color: cardColor,
            child: ListTile(
              title: Text(
                part.partName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Part No: ${part.partNumber}'),
                  Text('Qty: ${part.quantity}'),
                  Text('Stock Level: ${part.stockLevel}'),
                  const SizedBox(height: 4),
                  Text(
                    'Status: $statusText',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: trailingWidget,
            ),
          );
        },
      ),
    );
  }
}