import 'package:flutter/material.dart';
import 'auth.dart';
import 'mal_api.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<MalUser> _future;

  @override
  void initState() {
    super.initState();
    _future = MalApi.getMe();
  }

  Future<void> _signOut() async {
    await MalAuth.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        centerTitle: true,
        title: const Text('MAL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<MalUser>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            );
          }
          return _ProfileBody(user: snap.data!);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user});

  final MalUser user;

  @override
  Widget build(BuildContext context) {
    final stats = user.animeStats;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: user.pictureUrl == null
                    ? Container(width: 130, height: 180, color: const Color(0xFF222222))
                    : Image.network(user.pictureUrl!, width: 130, height: 180, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (user.joinedAt != null)
                      _IconLine(
                        icon: Icons.event_available,
                        text: _formatDate(user.joinedAt!),
                      ),
                    if (user.birthday != null) ...[
                      const SizedBox(height: 8),
                      _IconLine(icon: Icons.cake, text: user.birthday!),
                    ],
                    if (user.location != null && user.location!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _IconLine(icon: Icons.place, text: user.location!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (stats != null) _AnimeStatsBlock(stats: stats),
          const SizedBox(height: 24),
          const Text(
            'Manga stats are not exposed by the MAL API. Coming when scraping or v3 lands.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }
}

class _AnimeStatsBlock extends StatelessWidget {
  const _AnimeStatsBlock({required this.stats});
  final AnimeStatistics stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatColumn(label: 'Anime Days', value: stats.daysWatched.toStringAsFixed(1)),
            _StatColumn(label: 'Completed', value: '${stats.completed}'),
            _StatColumn(label: 'Mean Score', value: stats.meanScore.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 8),
        _StatusBar(stats: stats),
        const SizedBox(height: 8),
        Text(
          '${_thousands(stats.totalItems)} Anime List Entries',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.stats});
  final AnimeStatistics stats;

  @override
  Widget build(BuildContext context) {
    final total = (stats.watching +
            stats.completed +
            stats.onHold +
            stats.dropped +
            stats.planToWatch)
        .clamp(1, 1 << 31);
    final segs = <_Seg>[
      _Seg(stats.watching, const Color(0xFF49C26B)), // green
      _Seg(stats.completed, const Color(0xFF2D7BE5)), // blue
      _Seg(stats.onHold, const Color(0xFFE5B72D)), // yellow
      _Seg(stats.dropped, const Color(0xFFE54A4A)), // red
      _Seg(stats.planToWatch, const Color(0xFF888888)), // grey
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final s in segs)
              Expanded(
                flex: s.value == 0 ? 0 : s.value,
                child: Container(color: s.color),
              ),
            // ensure non-zero width if all are 0
            if (total == 0)
              const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

class _Seg {
  final int value;
  final Color color;
  _Seg(this.value, this.color);
}
