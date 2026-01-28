import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/notifications_page.dart'; // ikut path sebenar file kau


import '../../services/gig_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = GigService();
  final _searchCtrl = TextEditingController();

  String _category = 'All';
  String _search = '';

  final List<String> _categories = const [
    'All',
    'General',
    'Design',
    'Tutoring',
    'Coding',
    'Video Editing',
    'Writing',
    'Cleaning',
    'Electrical',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return 0.0;
  }

  IconData _catIcon(String c) {
    switch (c) {
      case 'General':
        return Icons.work_outline;
      case 'Design':
        return Icons.brush_outlined;
      case 'Tutoring':
        return Icons.school_outlined;
      case 'Coding':
        return Icons.code;
      case 'Video Editing':
        return Icons.video_camera_back_outlined;
      case 'Writing':
        return Icons.edit_note_outlined;
      case 'Cleaning':
        return Icons.cleaning_services_outlined;
      case 'Electrical':
        return Icons.electrical_services_outlined;
      default:
        return Icons.work_outline;
    }
  }

  Widget _chip({
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ pill yang tak overflow: ada maxWidth + Text ellipsis
  Widget _pill({
    required String text,
    required IconData icon,
    required Color bg,
    required Color fg,
    required Color border,
    double? maxWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      child: Container(
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
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
  title: const Text('UniGIG'),
  actions: [
    IconButton(
      tooltip: 'Notifications',
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsPage(userId: uid),
          ),
        );
      },
    ),
  ],
),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Find students offering skills near you.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),

            // Search
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                  hintText: 'Search services…',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final selected = _category == c;

                  return _chip(
                    text: c,
                    icon: c == 'All' ? Icons.grid_view_rounded : _catIcon(c),
                    selected: selected,
                    onTap: () => setState(() => _category = c),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.streamGigs(category: _category),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load gigs right now.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  // newest first
                  final sortedDocs = [...docs]..sort((a, b) {
                    final aTs = a.data()['createdAt'];
                    final bTs = b.data()['createdAt'];

                    final aMillis = (aTs is Timestamp) ? aTs.millisecondsSinceEpoch : 0;
                    final bMillis = (bTs is Timestamp) ? bTs.millisecondsSinceEpoch : 0;

                    return bMillis.compareTo(aMillis);
                  });

                  // search by title
                  final filtered = sortedDocs.where((d) {
                    final title = (d.data()['title'] ?? '').toString().toLowerCase();
                    if (_search.isEmpty) return true;
                    return title.contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No services found.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final data = doc.data();

                      final title = (data['title'] ?? '').toString();
                      final category = (data['category'] ?? 'General').toString();
                      final desc = (data['description'] ?? '').toString().trim();
                      final active = (data['active'] ?? true) == true;

                      final price = _toDouble(data['price']);

                      final requiresLocation = (data['requiresLocation'] ?? false) == true;
                      final ratePerKm = _toDouble(data['ratePerKm'] ?? 0.0);

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => context.push('/gig/${doc.id}'),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // left icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _catIcon(category),
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // middle
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      // ✅ bagi pill maximum width ikut ruang (tolak sikit margin)
                                      final maxPill = (c.maxWidth * 0.92).clamp(120.0, 320.0);

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: cs.onSurface,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _pill(
                                                text: category,
                                                icon: Icons.category_outlined,
                                                bg: cs.surfaceContainerHighest,
                                                fg: cs.onSurfaceVariant,
                                                border: cs.outlineVariant,
                                                maxWidth: maxPill,
                                              ),
                                              _pill(
                                                text: active ? 'Active' : 'Inactive',
                                                icon: active ? Icons.circle : Icons.circle_outlined,
                                                bg: active ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                                                fg: active ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                                                border: cs.outlineVariant,
                                                maxWidth: maxPill,
                                              ),
                                              if (requiresLocation)
                                                _pill(
                                                  text: 'On-site • RM ${ratePerKm.toStringAsFixed(2)}/km',
                                                  icon: Icons.place_outlined,
                                                  bg: cs.surfaceContainerHighest,
                                                  fg: cs.onSurfaceVariant,
                                                  border: cs.outlineVariant,
                                                  maxWidth: maxPill,
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
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // right price fixed width
                                SizedBox(
                                  width: 84,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Text(
                                      'RM ${price.toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}
