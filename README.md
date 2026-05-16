# MyMediaList

A personal Flutter app for browsing my MyAnimeList account on Android. Built as a learning project.

## Features

- **Bottom nav** modeled on the official MAL app: Home / Movies / TV / Anime / Schedule (only Anime is wired up so far).
- **Anime tab**
  - Status filters across the top: All / Watching / Completed / On Hold / Dropped / Plan to Watch
  - Pinned header with centered entry count, refresh button (left), type filter + sort menu (right)
  - Sort: Alphabetical, Your Score, Score (MAL mean), Watched Episodes, Air Start Date, Last Updated
  - Type filter: All / TV / Movie / OVA / ONA / Special / Music
  - Each row: poster, title, type/season, progress bar colored by status (green/blue/gold/rust/grey for watching/completed/on-hold/dropped/planned), personal score (left) + episodes (right)
  - Header + tab bar tint subtly when content is scrolled under them
  - Pagination handled (lists >1000 entries)
- **Search**: rounded pill search bar; debounced; results mirror the Anime tab rows (poster, type badge, score + member count) and drill into the detail page.
- **Detail page**
  - Poster gallery with dot indicator
  - Score (with number of users), Rank, Popularity, Members — right-aligned
  - Title, type/year/status/episodes/duration, genre chips
  - Expandable synopsis
  - **Information** section: English / Japanese / Synonyms / Aired / Studios / Source / Rating
  - **Related Entries**: 2-column compact grid with media type and relation (e.g. `TV · Sequel`, `Movie · Full story`)
  - **Characters & Voice Actors**: horizontally scrolling cards with character image (name + role overlaid) above the Japanese voice-actor image. Main characters first, then sorted by favorites
  - **Music**: row-aligned table of opening/ending themes (Jikan-sourced)
  - **Recommendations**: horizontally scrolling poster cards with the number of users who recommended each entry
  - **Score Stats**: per-score histogram (10→1) with vote counts (Jikan-sourced)
  - **Platforms**: tappable chips that launch streaming services (Crunchyroll, Netflix, etc.) — Jikan-sourced
- **Profile page** (requires OAuth login): avatar, joined date, anime statistics, status distribution bar.
- **Auth**: MAL OAuth 2.0 PKCE flow. Tokens stored via `flutter_secure_storage` (Android Keystore).

## Project layout

```
lib/
  main.dart              MyApp + HomeShell + AnimeListPage + status tabs + sort
  mal_api.dart           HTTP client, MAL models
  auth.dart              MalAuth — PKCE flow + secure token storage
  profile_page.dart      User profile screen
  anime_search_page.dart Debounced search
  anime_detail_page.dart Detail screen (poster gallery, info, related)
  config.dart            Client ID + username (GITIGNORED — see below)
```

`CLAUDE.md` has a fuller walkthrough of architecture, API choices, and known gaps.

## Setup

1. Install Flutter (developed against 3.41.x stable) and the Android toolchain.
2. Register an app at <https://myanimelist.net/apiconfig> with:
   - **App type**: `other`
   - **Redirect URI**: `mymedialist://oauth/callback`
3. Create `lib/config.dart` (gitignored):
   ```dart
   const malClientId = 'YOUR_CLIENT_ID';
   const malUsername = 'your_mal_username';
   ```
4. `flutter pub get`
5. `flutter run`

## Status

This is an in-progress personal project. Notable gaps:

- No OAuth refresh-token handling — expired tokens require re-login.
- Read-only: no PATCH calls to update list status, score, or progress yet.
- Username for list reads is hardcoded; should pivot to `@me` once OAuth is required.
- Manga stats / Producers / Licensors / Themes / Favorites count aren't exposed by the MAL API and would need page scraping.
- Home / Movies / TV / Schedule tabs are placeholders.

## API notes

- MAL API v2 base: `https://api.myanimelist.net/v2`
- Two auth modes coexist:
  - `X-MAL-CLIENT-ID` header for public list/search/detail reads
  - Bearer token (OAuth PKCE) for `/users/@me`
- `code_challenge_method=plain` — MAL has historically been unreliable with S256.
- `nsfw=true` is set on list queries; without it, list counts disagree with the MAL web UI.
