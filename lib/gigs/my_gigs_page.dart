import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ FIX Timestamp

import '../services/gig_service.dart';

class MyGigsPage extends StatelessWidget {
  const MyGigsPage({super.key});

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final service = GigService();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Gigs')),
      body: StreamBuilder(
        stream: service.streamMyGigs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error:\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.work_outline, size: 56, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'You have no gigs yet.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your first gig and start offering services.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => context.push('/create-gig'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create your first gig'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ✅ sort newest first (safe even if createdAt null)
          final sorted = [...docs]..sort((a, b) {
            final aTs = a.data()['createdAt'];
            final bTs = b.data()['createdAt'];

            final aMillis = (aTs is Timestamp) ? aTs.millisecondsSinceEpoch : 0;
            final bMillis = (bTs is Timestamp) ? bTs.millisecondsSinceEpoch : 0;

            return bMillis.compareTo(aMillis);
          });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              // ✅ header guide (NO BOX)
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tap a gig to view • Long-press for actions",
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Text(
                          '${sorted.length}',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final doc = sorted[i - 1];
              final d = doc.data();

              final title = (d['title'] ?? '').toString();
              final category = (d['category'] ?? 'General').toString();
              final desc = (d['description'] ?? '').toString().trim();

              final active = (d['active'] ?? true) == true;
              final price = _toDouble(d['price']);

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/gig/${doc.id}'),
                onLongPress: () => _showGigActions(context, doc.id, active),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.check_circle_outline, color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _Pill(
                                        text: category, // ✅ "Cleaning" auto readable
                                        icon: Icons.category_outlined,
                                        bg: cs.surfaceContainerHighest,
                                        fg: cs.onSurfaceVariant,
                                        border: cs.outlineVariant,
                                      ),
                                      _Pill(
                                        text: active ? 'Active' : 'Inactive',
                                        icon: active ? Icons.circle : Icons.circle_outlined,
                                        bg: active ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                                        fg: active ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                                        border: cs.outlineVariant,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Divider(color: cs.outlineVariant.withOpacity(0.7), height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.payments_outlined, size: 18, color: cs.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              'RM ${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: cs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              active ? 'On' : 'Off',
                              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 10),
                            Switch(
                              value: active,
                              onChanged: (v) async {
                                await service.toggleGigActive(gigId: doc.id, active: v);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(v ? 'Gig activated' : 'Gig deactivated')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-gig'),
        icon: const Icon(Icons.add),
        label: const Text('New Gig'),
      ),
    );
  }

  void _showGigActions(BuildContext context, String gigId, bool active) {
    final service = GigService();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Gig'),
              onTap: () {
                Navigator.pop(context);
                context.push('/edit-gig/$gigId');
              },
            ),
            ListTile(
              leading: const Icon(Icons.toggle_on),
              title: Text(active ? 'Set Inactive' : 'Set Active'),
              onTap: () async {
                Navigator.pop(context);
                await service.toggleGigActive(gigId: gigId, active: !active);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Gig'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete gig?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await service.deleteGig(gigId);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color border;

  const _Pill({
    required this.text,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
