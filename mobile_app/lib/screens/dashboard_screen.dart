import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../services/ble_service.dart';
import 'pairing_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Color _getStatusColor(TempStatus status) {
    switch (status) {
      case TempStatus.normal:
        return const Color(0xFF10B981); // GREEN
      case TempStatus.high:
        return const Color(0xFFEF4444); // RED
      case TempStatus.low:
        return const Color(0xFF3B82F6); // BLUE
      case TempStatus.disconnected:
      default:
        return const Color(0xFF6B7280); // GRAY
    }
  }

  String _getStatusText(TempStatus status) {
    switch (status) {
      case TempStatus.normal:
        return "NORMAL";
      case TempStatus.high:
        return "HIGH ALERT";
      case TempStatus.low:
        return "LOW ALERT";
      case TempStatus.disconnected:
      default:
        return "DISCONNECTED";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleService = BleService();

    return ListenableBuilder(
      listenable: bleService,
      builder: (context, _) {
        final statusColor = _getStatusColor(bleService.currentStatus);
        final statusText = _getStatusText(bleService.currentStatus);
        final formattedTime = bleService.lastUpdated != null
            ? DateFormat('hh:mm:ss a').format(bleService.lastUpdated!)
            : 'N/A';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bleService.isConnected
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: bleService.isConnected
                        ? const Color(0xFF0284C7).withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          bleService.isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: bleService.isConnected
                              ? const Color(0xFF0284C7)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bleService.isConnected
                                  ? (bleService.connectedDevice?.platformName ?? "TempGuard ESP32")
                                  : "Device Disconnected",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              bleService.isConnected ? "BLE Stream Active" : "Pair to monitor",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PairingScreen()),
                        );
                      },
                      child: Text(bleService.isConnected ? "Manage" : "Pair Device"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Temperature Monitor Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.thermostat, color: statusColor, size: 28),
                        const SizedBox(width: 8),
                        const Text(
                          "LIVE TEMPERATURE",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      bleService.isConnected
                          ? "${bleService.currentTemperature.toStringAsFixed(1)}°C"
                          : "--.-°C",
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: bleService.isConnected
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          "Last Updated: $formattedTime",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Threshold Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Configured Limits",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "MIN TEMP",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${bleService.minTempLimit.toStringAsFixed(1)} °C",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "MAX TEMP",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${bleService.maxTempLimit.toStringAsFixed(1)} °C",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
