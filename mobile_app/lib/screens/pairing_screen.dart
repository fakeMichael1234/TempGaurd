import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleService = BleService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Device Pairing"),
      ),
      body: ListenableBuilder(
        listenable: bleService,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scan Control Bar
                Card(
                  elevation: 0,
                  color: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "BLE Device Scanner",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bleService.isScanning
                                  ? "Scanning for TempGuard..."
                                  : "Tap scan to search",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bleService.isScanning
                                ? Colors.red.shade600
                                : const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (bleService.isScanning) {
                              bleService.stopScan();
                            } else {
                              bleService.startScan();
                            }
                          },
                          icon: Icon(
                            bleService.isScanning ? Icons.stop : Icons.search,
                          ),
                          label: Text(bleService.isScanning ? "Stop" : "Scan"),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "AVAILABLE DEVICES",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 10),

                // Device List
                Expanded(
                  child: bleService.scanResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bluetooth_searching,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                bleService.isScanning
                                    ? "Searching for nearby TempGuard BLE..."
                                    : "No TempGuard devices found.",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: bleService.scanResults.length,
                          itemBuilder: (context, index) {
                            final result = bleService.scanResults[index];
                            final device = result.device;
                            final isThisConnected =
                                bleService.connectedDevice?.remoteId == device.remoteId &&
                                    bleService.isConnected;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isThisConnected
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade200,
                                  width: isThisConnected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                                title: Text(
                                device.platformName.isNotEmpty
                                    ? device.platformName
                                    : "Unknown Device",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                                subtitle: Text(
                                "ID: ${device.remoteId} | RSSI: ${result.rssi} dBm",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                                trailing: bleService.isConnecting &&
                                      bleService.connectedDevice?.remoteId == device.remoteId
                                  ? const CircularProgressIndicator()
                                  : isThisConnected
                                      ? OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                          ),
                                          onPressed: () =>
                                              bleService.disconnectDevice(),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text("Disconnect"),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7),
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              bleService.connectToDevice(device),
                                          child: const Text("Connect"),
                                        ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
