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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
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
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (q) {
            final trimmed = q.trim();
            if (trimmed.isNotEmpty) _runSearch(trimmed);
          },
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search anime',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _clear,
            ),
        ],
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
        return ScrollConfiguration(
          behavior:
              ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFF1F1F1F)),
            itemBuilder: (_, i) => _SearchRow(item: items[i]),
          ),
        );
      },
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.item});
  final AnimeSummary item;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 80,
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
                        fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text('id: ${item.id}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
