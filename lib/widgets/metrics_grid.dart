import 'package:flutter/material.dart';

class MetricsGrid extends StatelessWidget {
  final String fuelCost;
  final String trafficLevel;
  final String tollStatus;
  final String co2Emission;

  const MetricsGrid({
    super.key,
    required this.fuelCost,
    required this.trafficLevel,
    required this.tollStatus,
    required this.co2Emission,
  });

  Widget _buildMetricChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricChip(Icons.local_gas_station, fuelCost, "Fuel Cost"),
          _buildMetricChip(Icons.traffic, trafficLevel, "Traffic"),
          _buildMetricChip(Icons.toll, tollStatus, "Tolls"),
          _buildMetricChip(Icons.eco, co2Emission, "CO₂"),
        ],
      ),
    );
  }
}