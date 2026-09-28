import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AlertRecord> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await StorageService.getAlertHistory();
    setState(() {
      _history = list;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await StorageService.clearAlertHistory();
    _loadHistory();
  }

  Color _getStatusColor(TempStatus status) {
    switch (status) {
      case TempStatus.normal:
        return const Color(0xFF10B981);
      case TempStatus.high:
        return const Color(0xFFEF4444);
      case TempStatus.low:
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  String _getStatusTitle(TempStatus status) {
    switch (status) {
      case TempStatus.high:
        return "HIGH TEMPERATURE ALERT";
      case TempStatus.low:
        return "LOW TEMPERATURE ALERT";
      case TempStatus.normal:
        return "RETURNED TO NORMAL";
      default:
        return "UNKNOWN";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ALERT EVENT LOGS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFF64748B),
                ),
              ),
              if (_history.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                  label: const Text(
                    "Clear Log",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "No alert history recorded yet.",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final record = _history[index];
                            final color = _getStatusColor(record.status);
                            final formattedDate =
                                DateFormat('MMM dd, yyyy - hh:mm:ss a')
                                    .format(record.timestamp);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Icon(
                                    record.status == TempStatus.high
                                        ? Icons.arrow_upward
                                        : record.status == TempStatus.low
                                            ? Icons.arrow_downward
                                            : Icons.check,
                                    color: color,
                                  ),
                                ),
                                title: Text(
                                  _getStatusTitle(record.status),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  formattedDate,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: Text(
                                  "${record.temperature.toStringAsFixed(1)} °C",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
