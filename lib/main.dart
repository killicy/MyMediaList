import 'package:flutter/material.dart';
import 'anime_detail_page.dart';
import 'anime_search_page.dart';
import 'auth.dart';
import 'config.dart';
import 'mal_api.dart';
import 'profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyMediaList',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  String? _avatarUrl;
  bool _signedIn = false;
  bool _busy = false;

  static const _pages = <Widget>[
    _PlaceholderPage(label: 'Home'),
    _PlaceholderPage(label: 'Movies'),
    _PlaceholderPage(label: 'TV'),
    AnimeListPage(),
    _PlaceholderPage(label: 'Schedule'),
  ];

  @override
  void initState() {
    super.initState();
    _refreshSession();
  }

  Future<void> _refreshSession() async {
    final signedIn = await MalAuth.isSignedIn;
    if (!mounted) return;
    setState(() => _signedIn = signedIn);
    if (signedIn) {
      try {
        final me = await MalApi.getMe();
        if (!mounted) return;
        setState(() => _avatarUrl = me.pictureUrl);
      } catch (_) {
        // ignore — avatar will fall back to placeholder
      }
    } else {
      setState(() => _avatarUrl = null);
    }
  }

  Future<void> _onAvatarTap() async {
    if (_busy) return;
    if (_signedIn) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ProfilePage(),
      ));
      _refreshSession();
      return;
    }
    setState(() => _busy = true);
    try {
      await MalAuth.signIn();
      await _refreshSession();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: _onAvatarTap,
            child: _busy
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF222222),
                    backgroundImage:
                        _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                    child: _avatarUrl == null
                        ? const Icon(Icons.person_outline,
                            color: Colors.white70, size: 20)
                        : null,
                  ),
          ),
        ),
        centerTitle: true,
        title: const Text('MAL',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        actions: [
          if (_index == 3)
            IconButton(
              tooltip: 'Search anime',
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnimeSearchPage()),
              ),
            ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_outlined),
            activeIcon: Icon(Icons.movie),
            label: 'Movies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tv_outlined),
            activeIcon: Icon(Icons.tv),
            label: 'TV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.animation_outlined),
            activeIcon: Icon(Icons.animation),
            label: 'Anime',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 24),
      ),
    );
  }
}

class AnimeListPage extends StatefulWidget {
  const AnimeListPage({super.key});

  @override
  State<AnimeListPage> createState() => _AnimeListPageState();
}

enum ListSort {
  alphabetical,
  score,
  mean,
  watched,
  airStart,
  lastUpdated,
}

extension on ListSort {
  String get label => switch (this) {
        ListSort.alphabetical => 'Alphabetical',
        ListSort.score => 'Your Score',
        ListSort.mean => 'Score',
        ListSort.watched => 'Watched Episodes',
        ListSort.airStart => 'Air Start Date',
        ListSort.lastUpdated => 'Last Updated',
      };
}

enum TypeFilter { all, tv, movie, ova, ona, special, music }

extension on TypeFilter {
  String get label => switch (this) {
        TypeFilter.all => 'All Types',
        TypeFilter.tv => 'TV',
        TypeFilter.movie => 'Movie',
        TypeFilter.ova => 'OVA',
        TypeFilter.ona => 'ONA',
        TypeFilter.special => 'Special',
        TypeFilter.music => 'Music',
      };

  /// Raw API media_type value. `null` means "no filter".
  String? get apiValue => switch (this) {
        TypeFilter.all => null,
        TypeFilter.tv => 'tv',
        TypeFilter.movie => 'movie',
        TypeFilter.ova => 'ova',
        TypeFilter.ona => 'ona',
        TypeFilter.special => 'special',
        TypeFilter.music => 'music',
      };
}

class _AnimeListPageState extends State<AnimeListPage>
    with SingleTickerProviderStateMixin {
  static const _statuses = <(String, String?)>[
    ('All', null),
    ('Watching', 'watching'),
    ('Completed', 'completed'),
    ('On Hold', 'on_hold'),
    ('Dropped', 'dropped'),
    ('Plan to Watch', 'plan_to_watch'),
  ];
  static const _initialIndex = 1; // Watching

  late final TabController _tabs;
  final Map<int, Future<List<AnimeListEntry>>> _cache = {};
  int _activeIndex = _initialIndex;
  ListSort _sort = ListSort.lastUpdated;
  TypeFilter _typeFilter = TypeFilter.all;
  bool _scrolledUnder = false;

  bool _onScroll(ScrollNotification n) {
    final under = n.metrics.pixels > 0;
    if (under != _scrolledUnder) {
      setState(() => _scrolledUnder = under);
    }
    return false;
  }

  List<AnimeListEntry> _filteredAndSorted(List<AnimeListEntry> items) {
    final filter = _typeFilter.apiValue;
    final out = [
      for (final e in items)
        if (filter == null || e.mediaType == filter) e,
    ];
    switch (_sort) {
      case ListSort.alphabetical:
        out.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case ListSort.score:
        out.sort((a, b) => b.score.compareTo(a.score));
      case ListSort.mean:
        out.sort((a, b) => (b.meanScore ?? -1).compareTo(a.meanScore ?? -1));
      case ListSort.watched:
        out.sort((a, b) => b.episodesWatched.compareTo(a.episodesWatched));
      case ListSort.airStart:
        out.sort((a, b) => b.airStartKey.compareTo(a.airStartKey));
      case ListSort.lastUpdated:
        out.sort((a, b) {
          final at = a.updatedAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.updatedAt?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _statuses.length,
      vsync: this,
      initialIndex: _initialIndex,
    );
    _tabs.addListener(_onTabChange);
    _load(_activeIndex);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == _activeIndex) return;
    setState(() {
      _activeIndex = _tabs.index;
      _load(_activeIndex);
    });
  }

  Future<List<AnimeListEntry>> _load(int i) {
    return _cache.putIfAbsent(
      i,
      () => MalApi.getUserAnimeList(malUsername, status: _statuses[i].$2),
    );
  }

  Future<void> _refresh() async {
    _cache.remove(_activeIndex);
    final next = _load(_activeIndex);
    setState(() {});
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: _scrolledUnder
                ? const Color(0xFF1A1A1A)
                : const Color(0xFF111111),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2,
              dividerColor: _scrolledUnder
                  ? const Color(0xFF2E2E2E)
                  : const Color(0xFF1F1F1F),
              dividerHeight: 1,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontSize: 15),
              tabs: [for (final s in _statuses) Tab(text: s.$1)],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AnimeListEntry>>(
              future: _load(_activeIndex),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                final items = _filteredAndSorted(snap.data ?? const []);
                return Column(
                  children: [
                    _ListHeader(
                      count: items.length,
                      sort: _sort,
                      onSortChanged: (v) => setState(() => _sort = v),
                      typeFilter: _typeFilter,
                      onTypeFilterChanged: (v) =>
                          setState(() => _typeFilter = v),
                      onRefresh: _refresh,
                      scrolledUnder: _scrolledUnder,
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(overscroll: false),
                          child: ListView.separated(
                            physics: const ClampingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: Color(0xFF1F1F1F)),
                            itemBuilder: (_, i) => _AnimeRow(entry: items[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'watching':
      return const Color(0xFF49C26B); // green
    case 'completed':
      return const Color(0xFF2D7BE5); // blue
    case 'on_hold':
      return const Color(0xFFE5B72D); // golden
    case 'dropped':
      return const Color(0xFFB7410E); // rust
    case 'plan_to_watch':
      return const Color(0xFF888888); // grey
    default:
      return const Color(0xFF49C26B);
  }
}

class _AnimeRow extends StatelessWidget {
  const _AnimeRow({required this.entry});

  final AnimeListEntry entry;

  @override
  Widget build(BuildContext context) {
    final total = entry.totalEpisodes ?? 0;
    final watched = entry.episodesWatched;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnimeDetailPage(
            id: entry.id,
            fallbackTitle: entry.title,
            fallbackPictureUrl: entry.pictureUrl,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 90,
                height: 120,
                child: entry.pictureUrl == null
                    ? Container(color: const Color(0xFF222222))
                    : Image.network(entry.pictureUrl!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: entry.progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor:
                            AlwaysStoppedAnimation(_statusColor(entry.status)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (entry.score > 0) ...[
                          const Icon(Icons.star,
                              color: Color(0xFFE5B72D), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          total > 0 ? '$watched / $total ep' : '$watched ep',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.count,
    required this.sort,
    required this.onSortChanged,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.onRefresh,
    required this.scrolledUnder,
  });

  final int count;
  final ListSort sort;
  final ValueChanged<ListSort> onSortChanged;
  final TypeFilter typeFilter;
  final ValueChanged<TypeFilter> onTypeFilterChanged;
  final VoidCallback onRefresh;
  final bool scrolledUnder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scrolledUnder ? const Color(0xFF1A1A1A) : const Color(0xFF111111),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center the count on the screen regardless of left/right buttons.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart,
                    color: Colors.blueAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$count Entries',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: onRefresh,
                ),
                const Spacer(),
                PopupMenuButton<TypeFilter>(
              tooltip: 'Filter by type',
              icon: Icon(
                Icons.filter_list,
                color: typeFilter == TypeFilter.all
                    ? Colors.white70
                    : Colors.blueAccent,
              ),
              color: const Color(0xFF1E1E1E),
              initialValue: typeFilter,
              onSelected: onTypeFilterChanged,
              itemBuilder: (_) => [
                for (final t in TypeFilter.values)
                  PopupMenuItem<TypeFilter>(
                    value: t,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Icon(
                          typeFilter == t
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: typeFilter == t
                              ? Colors.blueAccent
                              : Colors.white38,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            PopupMenuButton<ListSort>(
              tooltip: 'Sort',
              icon: const Icon(Icons.tune, color: Colors.white70),
              color: const Color(0xFF1E1E1E),
              initialValue: sort,
              onSelected: onSortChanged,
              itemBuilder: (_) => [
                for (final s in ListSort.values)
                  PopupMenuItem<ListSort>(
                    value: s,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Icon(
                          sort == s
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color:
                              sort == s ? Colors.blueAccent : Colors.white38,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
