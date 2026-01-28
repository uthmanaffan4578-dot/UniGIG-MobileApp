import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // belum ready
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        // belum login / session belum restore
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please login to view notifications.')),
          );
        }

        final q = FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true);

        return Scaffold(
          appBar: AppBar(title: const Text('Notifications')),
          body: StreamBuilder<QuerySnapshot>(
            stream: q.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading notifications'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No notifications yet'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString();
                  final message = (data['message'] ?? '').toString();
                  final read = (data['read'] ?? false) as bool;

                  return ListTile(
                    leading: Icon(read ? Icons.notifications_none : Icons.notifications),
                    title: Text(
                      title,
                      style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.bold),
                    ),
                    subtitle: Text(message),
                    onTap: () async {
                      await docs[i].reference.update({'read': true});
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
