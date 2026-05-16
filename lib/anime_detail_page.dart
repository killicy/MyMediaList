import 'package:flutter/material.dart';
import 'mal_api.dart';

class AnimeDetailPage extends StatefulWidget {
  const AnimeDetailPage({
    super.key,
    required this.id,
    this.fallbackTitle,
    this.fallbackPictureUrl,
  });

  final int id;
  final String? fallbackTitle;
  final String? fallbackPictureUrl;

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  late Future<AnimeDetail> _future;
  late Future<List<AnimeCharacter>> _charactersFuture;
  late Future<({List<String> openings, List<String> endings})> _themesFuture;
  bool _synopsisExpanded = false;
  bool _infoExpanded = false;
  bool _relatedExpanded = false;
  bool _musicExpanded = false;

  @override
  void initState() {
    super.initState();
    _future = MalApi.getAnimeDetail(widget.id);
    _charactersFuture = MalApi.getAnimeCharacters(widget.id);
    _themesFuture = MalApi.getAnimeThemes(widget.id);
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
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        actions: const [
          // Stubs — wire up to favorites / sharing later.
          Icon(Icons.favorite_border, color: Colors.white70),
          SizedBox(width: 12),
          Icon(Icons.share, color: Colors.white70),
          SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<AnimeDetail>(
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
          return _DetailBody(
            detail: snap.data!,
            charactersFuture: _charactersFuture,
            themesFuture: _themesFuture,
            synopsisExpanded: _synopsisExpanded,
            infoExpanded: _infoExpanded,
            musicExpanded: _musicExpanded,
            relatedExpanded: _relatedExpanded,
            onToggleSynopsis: () =>
                setState(() => _synopsisExpanded = !_synopsisExpanded),
            onToggleInfo: () =>
                setState(() => _infoExpanded = !_infoExpanded),
            onToggleMusic: () =>
                setState(() => _musicExpanded = !_musicExpanded),
            onToggleRelated: () =>
                setState(() => _relatedExpanded = !_relatedExpanded),
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.charactersFuture,
    required this.themesFuture,
    required this.synopsisExpanded,
    required this.infoExpanded,
    required this.musicExpanded,
    required this.relatedExpanded,
    required this.onToggleSynopsis,
    required this.onToggleInfo,
    required this.onToggleMusic,
    required this.onToggleRelated,
  });

  final AnimeDetail detail;
  final Future<List<AnimeCharacter>> charactersFuture;
  final Future<({List<String> openings, List<String> endings})> themesFuture;
  final bool synopsisExpanded;
  final bool infoExpanded;
  final bool musicExpanded;
  final bool relatedExpanded;
  final VoidCallback onToggleSynopsis;
  final VoidCallback onToggleInfo;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleRelated;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (detail.mediaType != null) detail.mediaTypeLabel,
      if (detail.seasonYear != null) '${detail.seasonYear}',
      if (detail.status != null) detail.statusLabel,
      if (detail.numEpisodes != null && detail.numEpisodes! > 0)
        '${detail.numEpisodes} ep',
      if (detail.episodeDurationLabel != null) detail.episodeDurationLabel!,
    ];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView(
        physics: const ClampingScrollPhysics(),
        children: [
          _HeroBlock(detail: detail),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              detail.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final m in meta)
                    Text(m,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (detail.genres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < detail.genres.length; i++) ...[
                    Text(detail.genres[i],
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (i != detail.genres.length - 1)
                      const Text('·',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 14)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          if ((detail.synopsis ?? '').isNotEmpty)
            _Synopsis(
              text: detail.synopsis!,
              expanded: synopsisExpanded,
              onToggle: onToggleSynopsis,
            ),
          _InformationSection(
            entries: _infoEntries(detail),
            expanded: infoExpanded,
            onToggle: onToggleInfo,
          ),
          _RelatedEntriesSection(
            items: detail.relatedAnime,
            expanded: relatedExpanded,
            onToggle: onToggleRelated,
          ),
          _CharactersSection(future: charactersFuture),
          _MusicSection(
            future: themesFuture,
            expanded: musicExpanded,
            onToggle: onToggleMusic,
          ),
          _RelatedSection(
            title: 'Recommendations',
            items: detail.recommendations,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static List<(String, String)> _infoEntries(AnimeDetail d) {
    final out = <(String, String)>[];
    if (d.altTitleEn != null) out.add(('English', d.altTitleEn!));
    if (d.altTitleJa != null) out.add(('Japanese', d.altTitleJa!));
    if (d.altSynonyms.isNotEmpty) {
      out.add(('Synonyms', d.altSynonyms.join(', ')));
    }
    final aired = _airedLabel(d.startDate, d.endDate);
    if (aired != null) out.add(('Aired', aired));
    if (d.studios.isNotEmpty) out.add(('Studios', d.studios.join(', ')));
    final source = _sourceLabel(d.source);
    if (source != null) out.add(('Source', source));
    final rating = _ratingLabel(d.rating);
    if (rating != null) out.add(('Rating', rating));
    return out;
  }

  static String? _airedLabel(String? start, String? end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    if (s == null && e == null) return null;
    if (s != null && e != null && s != e) return '$s to $e';
    return s ?? e;
  }

  static String? _formatDate(String? iso) {
    if (iso == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final parts = iso.split('-');
    if (parts.length == 1) return parts[0]; // year only
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return iso;
    if (parts.length < 3) return '${months[month - 1]} $year';
    final day = int.tryParse(parts[2]) ?? 0;
    return '${months[month - 1]} $day, $year';
  }

  static String? _sourceLabel(String? src) {
    if (src == null) return null;
    return src
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String? _ratingLabel(String? r) {
    switch (r) {
      case 'g': return 'G - All Ages';
      case 'pg': return 'PG - Children';
      case 'pg_13': return 'PG-13 - Teens 13 or older';
      case 'r': return 'R - 17+ (violence & profanity)';
      case 'r+': return 'R+ - Mild Nudity';
      case 'rx': return 'Rx - Hentai';
      default: return r;
    }
  }
}

class _HeroBlock extends StatefulWidget {
  const _HeroBlock({required this.detail});
  final AnimeDetail detail;

  @override
  State<_HeroBlock> createState() => _HeroBlockState();
}

class _HeroBlockState extends State<_HeroBlock> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final pics = d.pictures;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: pics.isEmpty
                      ? Container(color: const Color(0xFF222222))
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: pics.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) =>
                              Image.network(pics[i], fit: BoxFit.contain),
                        ),
                ),
                if (pics.length > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pics.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page
                                ? Colors.white
                                : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Score',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      d.mean == null ? 'N/A' : d.mean!.toStringAsFixed(2),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (d.numScoringUsers != null && d.numScoringUsers! > 0)
                  Text(
                    '${_thousands(d.numScoringUsers!)} users',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                const SizedBox(height: 16),
                _StatLine(label: 'Rank', value: _hashNum(d.rank)),
                const SizedBox(height: 12),
                _StatLine(label: 'Popularity', value: _hashNum(d.popularity)),
                const SizedBox(height: 12),
                _StatLine(
                  label: 'Members',
                  value: d.numListUsers == null
                      ? '—'
                      : _thousands(d.numListUsers!),
                  valueColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hashNum(int? n) => n == null ? '—' : '#${_thousands(n)}';

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

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    this.valueColor = Colors.blueAccent,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({
    required this.entries,
    required this.expanded,
    required this.onToggle,
  });

  final List<(String, String)> entries;
  final bool expanded;
  final VoidCallback onToggle;

  static const _collapsedCount = 4;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final canCollapse = entries.length > _collapsedCount;
    final shown = expanded || !canCollapse
        ? entries
        : entries.sublist(0, _collapsedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: Color(0xFF1F1F1F)),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in shown) ...[
                _InfoRow(label: e.$1, value: e.$2),
                const SizedBox(height: 6),
              ],
              if (canCollapse)
                Center(
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 24),
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white54,
                    ),
                    onPressed: onToggle,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.4),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Synopsis extends StatelessWidget {
  const _Synopsis({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4),
            ),
            secondChild: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.4),
            ),
          ),
          Center(
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
              icon: Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white54,
              ),
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedEntriesSection extends StatelessWidget {
  const _RelatedEntriesSection({
    required this.items,
    required this.expanded,
    required this.onToggle,
  });

  final List<RelatedAnime> items;
  final bool expanded;
  final VoidCallback onToggle;

  static const _collapsedCount = 4;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final canCollapse = items.length > _collapsedCount;
    final shown =
        expanded || !canCollapse ? items : items.sublist(0, _collapsedCount);

    final rows = <Widget>[];
    for (var i = 0; i < shown.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _RelatedCard(item: shown[i])),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < shown.length
                    ? _RelatedCard(item: shown[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFF1F1F1F)),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Related Entries',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: rows),
        ),
        if (canCollapse)
          Center(
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
              icon: Icon(
                expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white54,
              ),
              onPressed: onToggle,
            ),
          ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.item});
  final RelatedAnime item;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 56,
            child: item.pictureUrl == null
                ? Container(color: const Color(0xFF222222))
                : Image.network(item.pictureUrl!, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (item.mediaTypeLabel != null) item.mediaTypeLabel!,
                    if (item.relationType.isNotEmpty) item.relationType,
                  ].join(' · '),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({required this.title, required this.items});

  final String title;
  final List<RelatedAnime> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFF1F1F1F)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = items[i];
              return SizedBox(
                width: 100,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnimeDetailPage(
                        id: item.id,
                        fallbackTitle: item.title,
                        fallbackPictureUrl: item.pictureUrl,
                      ),
                    ),
                  ),
                  child: _PosterTile(
                    imageUrl: item.pictureUrl,
                    primary: item.title,
                    secondary: item.relationType,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CharactersSection extends StatelessWidget {
  const _CharactersSection({required this.future});
  final Future<List<AnimeCharacter>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AnimeCharacter>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snap.hasError) return const SizedBox.shrink();
        final items = snap.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF1F1F1F)),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Characters & Voice Actors',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 286,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _CharacterCard(item: items[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.item});
  final AnimeCharacter item;

  @override
  Widget build(BuildContext context) {
    final va = item.voiceActor;
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PosterTile(
            imageUrl: item.imageUrl,
            primary: item.name,
            secondary: item.role,
          ),
          const SizedBox(height: 6),
          if (va != null)
            _PosterTile(
              imageUrl: va.imageUrl,
              primary: va.name,
              secondary: '',
            )
          else
            const AspectRatio(
              aspectRatio: 3 / 4,
              child: SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.imageUrl,
    required this.primary,
    required this.secondary,
  });

  final String? imageUrl;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl == null
                ? Container(color: const Color(0xFF222222))
                : Image.network(imageUrl!, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      primary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                    if (secondary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            height: 1.15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicSection extends StatelessWidget {
  const _MusicSection({
    required this.future,
    required this.expanded,
    required this.onToggle,
  });
  final Future<({List<String> openings, List<String> endings})> future;
  final bool expanded;
  final VoidCallback onToggle;

  static const _collapsedCount = 2;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<String> openings, List<String> endings})>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snap.hasError || snap.data == null) return const SizedBox.shrink();
        final openings = snap.data!.openings;
        final endings = snap.data!.endings;
        if (openings.isEmpty && endings.isEmpty) return const SizedBox.shrink();
        final canCollapse =
            openings.length > _collapsedCount || endings.length > _collapsedCount;
        List<String> trim(List<String> xs) =>
            expanded || !canCollapse || xs.length <= _collapsedCount
                ? xs
                : xs.sublist(0, _collapsedCount);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF1F1F1F)),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Music',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ThemeTable(
                openings: trim(openings),
                endings: trim(endings),
              ),
            ),
            if (canCollapse)
              Center(
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                  ),
                  onPressed: onToggle,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeTable extends StatelessWidget {
  const _ThemeTable({required this.openings, required this.endings});
  final List<String> openings;
  final List<String> endings;

  static const _headerStyle = TextStyle(
    color: Colors.white54,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _cellStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    height: 1.3,
  );
  static const _emptyStyle = TextStyle(color: Colors.white38, fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final rows = <TableRow>[
      const TableRow(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Opening', style: _headerStyle),
          ),
          SizedBox.shrink(),
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Ending', style: _headerStyle),
          ),
        ],
      ),
    ];
    final rowCount = openings.length > endings.length
        ? openings.length
        : endings.length;
    if (rowCount == 0) {
      rows.add(const TableRow(
        children: [
          Text('—', style: _emptyStyle),
          SizedBox.shrink(),
          Text('—', style: _emptyStyle),
        ],
      ));
    } else {
      for (var i = 0; i < rowCount; i++) {
        rows.add(TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: i < openings.length
                  ? Text(openings[i], style: _cellStyle)
                  : const SizedBox.shrink(),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: i < endings.length
                  ? Text(endings[i], style: _cellStyle)
                  : const SizedBox.shrink(),
            ),
          ],
        ));
      }
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FixedColumnWidth(16),
        2: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows,
    );
  }
}
