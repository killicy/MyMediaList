import 'dart:async';
import 'package:flutter/material.dart';
import 'anime_detail_page.dart';
import 'mal_api.dart';

class AnimeSearchPage extends StatefulWidget {
  const AnimeSearchPage({super.key});

  @override
  State<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends State<AnimeSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  Future<List<AnimeSummary>>? _future;
  String _activeQuery = '';
  bool _scrolledUnder = false;

  bool _onScroll(ScrollNotification n) {
    final under = n.metrics.pixels > 0;
    if (under != _scrolledUnder) {
      setState(() => _scrolledUnder = under);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Rebuild so the clear (X) icon appears/disappears as the text changes.
    setState(() {});
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.length < 3) {
      setState(() {
        _future = null;
        _activeQuery = trimmed;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(trimmed));
  }

  void _runSearch(String q) {
    setState(() {
      _activeQuery = q;
      _future = MalApi.searchAnime(q, limit: 30);
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _future = null;
      _activeQuery = '';
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: _scrolledUnder
            ? const Color(0xFF1A1A1A)
            : const Color(0xFF111111),
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (q) {
                final trimmed = q.trim();
                if (trimmed.isNotEmpty) _runSearch(trimmed);
              },
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white70,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Icon(Icons.search,
                      color: Colors.white54, size: 20),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _clear,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.cancel,
                                color: Colors.white54, size: 20),
                          ),
                        ),
                      ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_future == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _activeQuery.isEmpty
                ? 'Type at least 3 characters to search.'
                : 'Keep typing — minimum 3 characters.',
            style: const TextStyle(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return FutureBuilder<List<AnimeSummary>>(
      future: _future,
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
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Center(
            child: Text('No results.',
                style: TextStyle(color: Colors.white54)),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFF1F1F1F)),
              itemBuilder: (_, i) => _SearchRow(item: items[i]),
            ),
          ),
        );
      },
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.item});
  final AnimeSummary item;

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final epAndSeason = <String>[
      if (item.numEpisodes != null && item.numEpisodes! > 0)
        '${item.numEpisodes} ep',
      if (item.seasonYear != null)
        '${item.seasonName == null ? '' : '${_capitalize(item.seasonName!)} '}${item.seasonYear}',
    ].join(', ');

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnimeDetailPage(
            id: item.id,
            fallbackTitle: item.title,
            fallbackPictureUrl: item.pictureUrl,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 90,
                height: 120,
                child: item.pictureUrl == null
                    ? Container(color: const Color(0xFF222222))
                    : Image.network(item.pictureUrl!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (item.mediaTypeLabel != null) ...[
                          _TypeBadge(label: item.mediaTypeLabel!),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            epAndSeason,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (item.mean != null) ...[
                          const Icon(Icons.star,
                              color: Color(0xFFE5B72D), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            item.mean!.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (item.numListUsers != null)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('·',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                            ),
                        ],
                        if (item.numListUsers != null) ...[
                          Text(
                            _thousands(item.numListUsers!),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.people_outline,
                              color: Colors.white54, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
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

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFB33A3A),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
