import 'package:flutter/material.dart';

class EmergencyGrid extends StatelessWidget {
  final bool isAmbulanceMode;
  final VoidCallback onKitTap;
  final VoidCallback onReportTap;
  final VoidCallback onAmbulanceTap;
  final VoidCallback onSOSTap;

  const EmergencyGrid({
    super.key,
    required this.isAmbulanceMode,
    required this.onKitTap,
    required this.onReportTap,
    required this.onAmbulanceTap,
    required this.onSOSTap,
  });

  Widget _buildActionIcon(String label, IconData icon, Color color, {bool isAlert = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              color: isAlert ? color.withOpacity(0.2) : Colors.transparent,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionIcon("Kit", Icons.medical_services_outlined, Colors.tealAccent, onTap: onKitTap),
        _buildActionIcon("Report", Icons.car_crash_outlined, Colors.orangeAccent, onTap: onReportTap),
        _buildActionIcon("Ambulance", Icons.airport_shuttle_outlined, Colors.yellow, onTap: onAmbulanceTap, isAlert: isAmbulanceMode),
        _buildActionIcon("SOS", Icons.sos, Colors.redAccent, isAlert: true, onTap: onSOSTap),
      ],
    );
  }
}