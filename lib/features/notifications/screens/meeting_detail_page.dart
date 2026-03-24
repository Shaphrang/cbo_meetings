//lib\features\notifications\screens\meeting_detail_page.dart
import 'package:flutter/material.dart';

class MeetingDetailPage extends StatelessWidget {
  final String meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meeting Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "Meeting ID: $meetingId",
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}