import 'package:flutter/material.dart';

class TransportModes extends StatelessWidget {
  final String selectedTransport;
  final Function(String) onTransportSelected;

  const TransportModes({
    super.key,
    required this.selectedTransport,
    required this.onTransportSelected,
  });

  Widget _buildTransportButton(String title, IconData icon) {
    bool isSelected = selectedTransport == title;
    return GestureDetector(
      onTap: () => onTransportSelected(title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : const Color(0xFF1E2D3A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 18),
            const SizedBox(width: 6),
            Text(
              title, 
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              )
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTransportButton('Car', Icons.directions_car),
          const SizedBox(width: 10),
          _buildTransportButton('Bike', Icons.two_wheeler),
          const SizedBox(width: 10),
          _buildTransportButton('Truck', Icons.local_shipping),
          const SizedBox(width: 10),
          _buildTransportButton('Walk', Icons.directions_walk),
        ],
      ),
    );
  }
}