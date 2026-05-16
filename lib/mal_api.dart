import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'config.dart';

class MalApi {
  static const _base = 'https://api.myanimelist.net/v2';
  static const _headers = {'X-MAL-CLIENT-ID': malClientId};

  static Future<Map<String, String>> _authHeaders() async {
    final token = await MalAuth.accessToken;
    if (token == null) {
      throw StateError('Not signed in');
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// Per-score vote breakdown for an anime, via Jikan. The MAL v2 API only
  /// exposes the *list status* distribution under `statistics`, not the
  /// score histogram shown on the website's stats page.
  static Future<ScoreStats> getAnimeScoreStats(int id) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$id/statistics');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Jikan ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return ScoreStats.fromJson(data);
  }

  /// Opening and ending theme song strings. Jikan's `/anime/{id}/full`
  /// returns them pre-formatted (e.g. `1: "Title" by Artist (eps 1-12)`).
  /// MAL's v2 API does not expose music themes.
  static Future<({List<String> openings, List<String> endings})>
      getAnimeThemes(int id) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$id/full');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Jikan ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final theme = data['theme'] as Map<String, dynamic>?;
    List<String> pull(String key) {
      final raw = theme?[key];
      if (raw is! List) return const [];
      return raw.whereType<String>().toList();
    }
    return (openings: pull('openings'), endings: pull('endings'));
  }

  /// Fetches characters via Jikan (free MAL proxy). MAL's official v2 API
  /// does not expose characters; Jikan does. Sorted by role (Main first,
  /// then Supporting, then everything else), and within each group by
  /// favorites desc.
  static Future<List<AnimeCharacter>> getAnimeCharacters(int id) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$id/characters');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Jikan ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List).cast<Map<String, dynamic>>();
    int rolePriority(String r) {
      switch (r.toLowerCase()) {
        case 'main':
          return 0;
        case 'supporting':
          return 1;
        default:
          return 2;
      }
    }
    final list = data.map(AnimeCharacter.fromJson).toList()
      ..sort((a, b) {
        final byRole = rolePriority(a.role).compareTo(rolePriority(b.role));
        if (byRole != 0) return byRole;
        return b.favorites.compareTo(a.favorites);
      });
    return list;
  }

  static Future<AnimeDetail> getAnimeDetail(int id) async {
    final uri = Uri.parse('$_base/anime/$id').replace(queryParameters: {
      'fields':
          'id,title,main_picture,pictures,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,media_type,status,genres,num_episodes,start_season,average_episode_duration,studios,source,rating,related_anime{node{id,title,main_picture,media_type},relation_type_formatted,relation_type},recommendations{node{id,title,main_picture,media_type},num_recommendations}',
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('MAL API ${res.statusCode}: ${res.body}');
    }
    return AnimeDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<MalUser> getMe() async {
    final uri = Uri.parse('$_base/users/@me').replace(queryParameters: {
      'fields': 'id,name,picture,gender,birthday,location,joined_at,anime_statistics',
    });
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw Exception('MAL API ${res.statusCode}: ${res.body}');
    }
    return MalUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<List<AnimeSummary>> searchAnime(String query, {int limit = 10}) async {
    final uri = Uri.parse('$_base/anime').replace(queryParameters: {
      'q': query,
      'limit': '$limit',
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('MAL API ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List).cast<Map<String, dynamic>>();
    return data
        .map((e) => AnimeSummary.fromNode(e['node'] as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AnimeListEntry>> getUserAnimeList(
    String userName, {
    String? status,
    int pageSize = 1000,
  }) async {
    Uri uri = Uri.parse('$_base/users/$userName/animelist').replace(
      queryParameters: {
        if (status != null) 'status': status,
        'fields': 'list_status,main_picture,num_episodes,media_type,start_season',
        'limit': '$pageSize',
        'sort': 'list_updated_at',
        'nsfw': 'true',
      },
    );

    final all = <AnimeListEntry>[];
    while (true) {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) {
        throw Exception('MAL API ${res.statusCode}: ${res.body}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      all.addAll(data.map(AnimeListEntry.fromJson));

      final next = (body['paging'] as Map?)?['next'] as String?;
      if (next == null) break;
      uri = Uri.parse(next);
    }
    return all;
  }
}

class AnimeDetail {
  final int id;
  final String title;
  final String? mainPictureLarge;
  final List<String> pictures; // additional pictures (large)
  final double? mean;
  final int? rank;
  final int? popularity;
  final int? numListUsers;
  final int? numScoringUsers;
  final String? mediaType;
  final String? status;
  final int? numEpisodes;
  final int? avgEpisodeSeconds;
  final int? seasonYear;
  final String? seasonName;
  final List<String> genres;
  final String? synopsis;
  final String? altTitleEn;
  final String? altTitleJa;
  final List<String> altSynonyms;
  final String? startDate;
  final String? endDate;
  final List<String> studios;
  final String? source;
  final String? rating;
  final List<RelatedAnime> relatedAnime;
  final List<RelatedAnime> recommendations;

  AnimeDetail({
    required this.id,
    required this.title,
    this.mainPictureLarge,
    this.pictures = const [],
    this.mean,
    this.rank,
    this.popularity,
    this.numListUsers,
    this.numScoringUsers,
    this.mediaType,
    this.status,
    this.numEpisodes,
    this.avgEpisodeSeconds,
    this.seasonYear,
    this.seasonName,
    this.genres = const [],
    this.synopsis,
    this.altTitleEn,
    this.altTitleJa,
    this.altSynonyms = const [],
    this.startDate,
    this.endDate,
    this.studios = const [],
    this.source,
    this.rating,
    this.relatedAnime = const [],
    this.recommendations = const [],
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> j) {
    final mainPic = (j['main_picture'] as Map?)?['large'] as String?;
    final pics = <String>[];
    if (mainPic != null) pics.add(mainPic);
    for (final p in (j['pictures'] as List? ?? const [])) {
      final url = (p as Map)['large'] as String?;
      if (url != null && url != mainPic) pics.add(url);
    }
    final season = j['start_season'] as Map<String, dynamic>?;
    final alts = j['alternative_titles'] as Map<String, dynamic>?;
    return AnimeDetail(
      id: j['id'] as int,
      title: j['title'] as String,
      mainPictureLarge: mainPic,
      pictures: pics,
      mean: (j['mean'] as num?)?.toDouble(),
      rank: j['rank'] as int?,
      popularity: j['popularity'] as int?,
      numListUsers: j['num_list_users'] as int?,
      numScoringUsers: j['num_scoring_users'] as int?,
      mediaType: j['media_type'] as String?,
      status: j['status'] as String?,
      numEpisodes: j['num_episodes'] as int?,
      avgEpisodeSeconds: j['average_episode_duration'] as int?,
      seasonYear: season?['year'] as int?,
      seasonName: season?['season'] as String?,
      genres: [
        for (final g in (j['genres'] as List? ?? const []))
          (g as Map)['name'] as String,
      ],
      synopsis: j['synopsis'] as String?,
      altTitleEn: _nonEmpty(alts?['en'] as String?),
      altTitleJa: _nonEmpty(alts?['ja'] as String?),
      altSynonyms: [
        for (final s in (alts?['synonyms'] as List? ?? const []))
          if ((s as String).isNotEmpty) s,
      ],
      startDate: _nonEmpty(j['start_date'] as String?),
      endDate: _nonEmpty(j['end_date'] as String?),
      studios: [
        for (final s in (j['studios'] as List? ?? const []))
          (s as Map)['name'] as String,
      ],
      source: _nonEmpty(j['source'] as String?),
      rating: _nonEmpty(j['rating'] as String?),
      relatedAnime: [
        for (final r in (j['related_anime'] as List? ?? const []))
          RelatedAnime.fromJson(r as Map<String, dynamic>),
      ],
      recommendations: [
        for (final r in (j['recommendations'] as List? ?? const []))
          RelatedAnime.fromRecommendation(r as Map<String, dynamic>),
      ],
    );
  }

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  String get mediaTypeLabel {
    switch (mediaType) {
      case 'tv': return 'TV';
      case 'ova': return 'OVA';
      case 'ona': return 'ONA';
      case 'movie': return 'Movie';
      case 'special': return 'Special';
      case 'music': return 'Music';
      default: return (mediaType ?? '').toUpperCase();
    }
  }

  String get statusLabel {
    switch (status) {
      case 'finished_airing': return 'Finished';
      case 'currently_airing': return 'Airing';
      case 'not_yet_aired': return 'Not yet aired';
      default: return status ?? '';
    }
  }

  String? get episodeDurationLabel {
    if (avgEpisodeSeconds == null || avgEpisodeSeconds! <= 0) return null;
    final mins = (avgEpisodeSeconds! / 60).round();
    return '$mins min';
  }
}

class ScoreStats {
  /// Buckets sorted descending by score (10..1).
  final List<ScoreBucket> buckets;

  ScoreStats({required this.buckets});

  factory ScoreStats.fromJson(Map<String, dynamic> j) {
    final scores = (j['scores'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ScoreBucket.fromJson)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ScoreStats(buckets: scores);
  }

  int get totalVotes => buckets.fold(0, (sum, b) => sum + b.votes);
}

class ScoreBucket {
  final int score;
  final int votes;
  final double percentage;

  ScoreBucket({
    required this.score,
    required this.votes,
    required this.percentage,
  });

  factory ScoreBucket.fromJson(Map<String, dynamic> j) => ScoreBucket(
        score: (j['score'] as num).toInt(),
        votes: (j['votes'] as num).toInt(),
        percentage: (j['percentage'] as num).toDouble(),
      );
}

class AnimeCharacter {
  final int id;
  final String name;
  final String? imageUrl;
  final String role; // 'Main' / 'Supporting'
  final int favorites;
  final VoiceActor? voiceActor;

  AnimeCharacter({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.role,
    this.favorites = 0,
    this.voiceActor,
  });

  factory AnimeCharacter.fromJson(Map<String, dynamic> j) {
    final c = j['character'] as Map<String, dynamic>;
    final images = c['images'] as Map<String, dynamic>?;
    final jpg = images?['jpg'] as Map<String, dynamic>?;
    final vas = (j['voice_actors'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    // Japanese VA only — no fallback to other languages.
    Map<String, dynamic>? va;
    for (final v in vas) {
      if ((v['language'] as String?)?.toLowerCase() == 'japanese') {
        va = v;
        break;
      }
    }
    return AnimeCharacter(
      id: c['mal_id'] as int,
      name: c['name'] as String,
      imageUrl: jpg?['image_url'] as String?,
      role: j['role'] as String? ?? '',
      favorites: (j['favorites'] as int?) ?? 0,
      voiceActor: va == null ? null : VoiceActor.fromJson(va),
    );
  }
}

class VoiceActor {
  final int id;
  final String name;
  final String? imageUrl;
  final String language;

  VoiceActor({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.language,
  });

  factory VoiceActor.fromJson(Map<String, dynamic> j) {
    final p = j['person'] as Map<String, dynamic>;
    final images = p['images'] as Map<String, dynamic>?;
    final jpg = images?['jpg'] as Map<String, dynamic>?;
    return VoiceActor(
      id: p['mal_id'] as int,
      name: p['name'] as String,
      imageUrl: jpg?['image_url'] as String?,
      language: j['language'] as String? ?? '',
    );
  }
}

class RelatedAnime {
  final int id;
  final String title;
  final String? pictureUrl;
  final String relationType;
  final String? mediaType; // raw API value: tv, movie, ova, ona, special, music

  RelatedAnime({
    required this.id,
    required this.title,
    this.pictureUrl,
    required this.relationType,
    this.mediaType,
  });

  factory RelatedAnime.fromJson(Map<String, dynamic> j) {
    final node = j['node'] as Map<String, dynamic>;
    return RelatedAnime(
      id: node['id'] as int,
      title: node['title'] as String,
      pictureUrl: (node['main_picture'] as Map?)?['medium'] as String?,
      relationType:
          (j['relation_type_formatted'] as String?) ?? (j['relation_type'] as String? ?? ''),
      mediaType: node['media_type'] as String?,
    );
  }

  /// Recommendations come from `/anime/{id}` with a different shape:
  /// `{ node, num_recommendations }`. We reuse RelatedAnime by mapping the
  /// count into the subtitle slot.
  factory RelatedAnime.fromRecommendation(Map<String, dynamic> j) {
    final node = j['node'] as Map<String, dynamic>;
    final n = (j['num_recommendations'] as int?) ?? 0;
    return RelatedAnime(
      id: node['id'] as int,
      title: node['title'] as String,
      pictureUrl: (node['main_picture'] as Map?)?['medium'] as String?,
      relationType: '$n user${n == 1 ? '' : 's'}',
      mediaType: node['media_type'] as String?,
    );
  }

  String? get mediaTypeLabel {
    switch (mediaType) {
      case 'tv': return 'TV';
      case 'ova': return 'OVA';
      case 'ona': return 'ONA';
      case 'movie': return 'Movie';
      case 'special': return 'Special';
      case 'music': return 'Music';
      case null: return null;
      default: return mediaType!.toUpperCase();
    }
  }
}

class MalUser {
  final int id;
  final String name;
  final String? pictureUrl;
  final String? joinedAt;
  final String? birthday;
  final String? location;
  final AnimeStatistics? animeStats;

  MalUser({
    required this.id,
    required this.name,
    this.pictureUrl,
    this.joinedAt,
    this.birthday,
    this.location,
    this.animeStats,
  });

  factory MalUser.fromJson(Map<String, dynamic> j) => MalUser(
        id: j['id'] as int,
        name: j['name'] as String,
        pictureUrl: j['picture'] as String?,
        joinedAt: j['joined_at'] as String?,
        birthday: j['birthday'] as String?,
        location: j['location'] as String?,
        animeStats: j['anime_statistics'] == null
            ? null
            : AnimeStatistics.fromJson(
                j['anime_statistics'] as Map<String, dynamic>),
      );
}

class AnimeStatistics {
  final double daysWatched;
  final int watching;
  final int completed;
  final int onHold;
  final int dropped;
  final int planToWatch;
  final int totalItems;
  final double meanScore;
  final int episodes;

  AnimeStatistics({
    required this.daysWatched,
    required this.watching,
    required this.completed,
    required this.onHold,
    required this.dropped,
    required this.planToWatch,
    required this.totalItems,
    required this.meanScore,
    required this.episodes,
  });

  factory AnimeStatistics.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0.0;
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return AnimeStatistics(
      daysWatched: d('num_days_watched'),
      watching: i('num_items_watching'),
      completed: i('num_items_completed'),
      onHold: i('num_items_on_hold'),
      dropped: i('num_items_dropped'),
      planToWatch: i('num_items_plan_to_watch'),
      totalItems: i('num_items'),
      meanScore: d('mean_score'),
      episodes: i('num_episodes'),
    );
  }
}

class AnimeSummary {
  final int id;
  final String title;
  final String? pictureUrl;

  AnimeSummary({required this.id, required this.title, this.pictureUrl});

  factory AnimeSummary.fromNode(Map<String, dynamic> n) => AnimeSummary(
        id: n['id'] as int,
        title: n['title'] as String,
        pictureUrl: (n['main_picture'] as Map?)?['medium'] as String?,
      );
}

class AnimeListEntry {
  final int id;
  final String title;
  final String? pictureUrl;
  final int? totalEpisodes;
  final String? mediaType;
  final int? seasonYear;
  final String? seasonName;
  final int episodesWatched;
  final int score;
  final DateTime? updatedAt;

  AnimeListEntry({
    required this.id,
    required this.title,
    this.pictureUrl,
    this.totalEpisodes,
    this.mediaType,
    this.seasonYear,
    this.seasonName,
    required this.episodesWatched,
    required this.score,
    this.updatedAt,
  });

  factory AnimeListEntry.fromJson(Map<String, dynamic> j) {
    final node = j['node'] as Map<String, dynamic>;
    final status = j['list_status'] as Map<String, dynamic>;
    final season = node['start_season'] as Map<String, dynamic>?;
    return AnimeListEntry(
      id: node['id'] as int,
      title: node['title'] as String,
      pictureUrl: (node['main_picture'] as Map?)?['medium'] as String?,
      totalEpisodes: node['num_episodes'] as int?,
      mediaType: node['media_type'] as String?,
      seasonYear: season?['year'] as int?,
      seasonName: season?['season'] as String?,
      episodesWatched: (status['num_episodes_watched'] as int?) ?? 0,
      score: (status['score'] as int?) ?? 0,
      updatedAt: DateTime.tryParse((status['updated_at'] as String?) ?? ''),
    );
  }

  static int _seasonOrder(String? s) =>
      switch (s) { 'winter' => 0, 'spring' => 1, 'summer' => 2, 'fall' => 3, _ => -1 };

  /// Year * 10 + season index. Higher = newer. Null start_season sorts last.
  int get airStartKey =>
      seasonYear == null ? -1 : (seasonYear! * 10 + _seasonOrder(seasonName));

  String get subtitle {
    final type = (mediaType ?? '').toUpperCase();
    if (seasonYear == null) return type;
    return '$type · $seasonYear ${seasonName ?? ''}'.trim();
  }

  double get progress {
    if (totalEpisodes == null || totalEpisodes! <= 0) return 0;
    return (episodesWatched / totalEpisodes!).clamp(0, 1).toDouble();
  }
}
