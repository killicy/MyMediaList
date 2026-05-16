# MyMediaList — Project Notes for Claude

A personal Flutter app for tracking anime/manga, reading from the MyAnimeList API.

## Stack

- **Flutter** 3.41.9 stable (SDK at `~/development/flutter`)
- **Dart** 3.11.5
- Runtime deps: `http`, `flutter_web_auth_2`, `flutter_secure_storage`
- Primary target: Android. Test device: AVD `flutter_pixel` (Pixel 8, API 36 Baklava, Google Play system image, x86_64).

## Run

```bash
~/Android/Sdk/emulator/emulator -avd flutter_pixel -no-snapshot-save -no-boot-anim &
flutter run -d emulator-5554
```

Emulator needs `/dev/kvm` access. User is in the `kvm` group; the device also has ACLs set via logind so that works even from sessions that started before the group add.

## Project naming (intentional split)

| What | Value | Why |
|---|---|---|
| Folder | `MyMediaList/` | Cosmetic |
| Display name (Android `android:label`, iOS `CFBundleDisplayName`) | `MyMediaList` | What shows under the launcher icon |
| Dart package name (`pubspec.yaml` `name:`) | `my_media_list` | Dart enforces `lowercase_with_underscores`. Do NOT change this — would break every `import 'package:my_media_list/...'`. |

## File layout

```
lib/
  main.dart              MyApp + HomeShell (AppBar w/ avatar + search + bottom nav)
                         + AnimeListPage (status tabs, pinned header, sort) + _ListHeader + _AnimeRow
                         + placeholder pages
  mal_api.dart           MalApi + models: AnimeSummary, AnimeListEntry, AnimeDetail, MalUser, AnimeStatistics
  auth.dart              MalAuth — PKCE OAuth flow + secure token storage
  profile_page.dart      ProfilePage — avatar, joined date, anime stats, status distribution bar
  anime_search_page.dart AnimeSearchPage — debounced text search, taps into AnimeDetailPage
  anime_detail_page.dart AnimeDetailPage — poster gallery, score/rank stats, genres, synopsis
  config.dart            malClientId, malUsername  (GITIGNORED — see below)
```

## Secrets

`lib/config.dart` is **gitignored** (see `.gitignore`). It contains:

```dart
const malClientId = '...';   // MAL OAuth Client ID
const malUsername = '...';   // hardcoded MAL user whose list we read
```

Username is hardcoded for now; the plan is to move to a settings screen / persisted prefs later.

## MAL API integration

- **App type registered: `other`** → PKCE flow, no client secret. A `web` type would have a secret that can't safely ship in a mobile binary.
- Two access modes coexist:
  - **Client-ID-only** (`X-MAL-CLIENT-ID` header) for public list/detail/search reads — used by `MalApi.searchAnime`, `getUserAnimeList`, `getAnimeDetail`.
  - **Bearer token** (OAuth PKCE) for `@me` profile data — used by `MalApi.getMe`. MAL refuses any `/v2/users/{name}` call without OAuth, even for public profiles.
- Endpoints used:
  - `GET /v2/anime?q=...` (client-id) — search page
  - `GET /v2/anime/{id}?fields=...` (client-id) — detail page
  - `GET /v2/users/{user}/animelist?status=...&fields=...&sort=list_updated_at&limit=1000&nsfw=true` (client-id) — Anime tab. Follows `paging.next` to handle lists >1000 entries.
  - `GET /v2/users/@me?fields=...,anime_statistics` (bearer) — Profile page
- **`nsfw=true` matters**: the API hides NSFW-tagged entries by default. Without it, list counts disagree with the MAL web UI.

## OAuth (PKCE)

- Endpoints: authorize `https://myanimelist.net/v1/oauth2/authorize`, token `https://myanimelist.net/v1/oauth2/token`.
- **`code_challenge_method=plain`** (i.e. `code_challenge == code_verifier`). MAL has been finicky about S256 historically; plain is the safe default. If we ever switch, update `_challengeMethod` in `lib/auth.dart` and replace verifier→challenge with a base64url-encoded SHA-256.
- **Redirect URI**: `mymedialist://oauth/callback` — must match the value registered in MAL's app config exactly.
- Android intent-filter for the redirect lives in `android/app/src/main/AndroidManifest.xml` as `com.linusu.flutter_web_auth_2.CallbackActivity` with `<data android:scheme="mymedialist" />`.
- **Token storage**: `flutter_secure_storage` (Android Keystore). Keys: `mal_access_token`, `mal_refresh_token`, `mal_expiry_epoch_ms`.
- **Refresh flow is NOT implemented yet** — when the access token expires, the user will get a 401 and need to sign out + back in. Refresh-token use would go in `MalAuth` next to `signIn()`.
- The `state` query param is checked on callback to defend against CSRF.

## UI

### Bottom nav (`HomeShell`)
5 fixed items: Home, Movies, TV, Anime, Schedule.
Style modeled on the MyAnimeList mobile app: flat dark bar (`#1A1A1A`), outline icons that fill when active, label visible on all tabs.

The `Icons.animation` glyph is the closest Material icon to "anime" — swap to a custom asset later if desired.

### Anime tab (`AnimeListPage`)
Models MAL's "My List" screen for the hardcoded user.

Layout (Column, top to bottom):
1. **Status TabBar** — horizontally scrollable, `isScrollable: true`, white underline indicator. Tabs: All / Watching / Completed / On Hold / Dropped / Plan to Watch. Defaults to Watching.
2. **Pinned `_ListHeader`** — stays put while the list scrolls. Shows `N Entries` (blue, with bar-chart icon) centered, sort `Icons.tune` on the right.
3. **List** — `ListView.separated` of `_AnimeRow` (90×120 poster, title, `TV · 2024 fall`, green progress bar, `watched / total ep`). Tap routes to `AnimeDetailPage`.

Behaviour:
- **Per-status cache**: `Map<int, Future<List<AnimeListEntry>>>` keyed by tab index. Switching tabs is instant after first load.
- **Sort** (`ListSort` enum) is applied client-side via `_sorted(items)` so switching sort is instant. Options: Alphabetical, Score, Watched Episodes, Air Start Date, Last Updated. Server-side `sort=list_updated_at` is what we ask for, then re-sorted locally per the user's selection.
- **No pull-to-refresh** (intentionally removed per user request). Cache only invalidates on app restart; add a refresh button in `_ListHeader` if needed.
- **Overscroll stretch is disabled** via `ScrollConfiguration(overscroll: false)` + `ClampingScrollPhysics` — same convention used throughout.

### Detail page (`AnimeDetailPage`)
Opened from list rows or search results. Fetches via `MalApi.getAnimeDetail`.

- **Hero block**: poster on the left in a `PageView` (swipe through additional pictures, dot indicator below).
  - Right column is **right-aligned** (`CrossAxisAlignment.end` + `TextAlign.right`) so Score / Rank / Popularity / Members all line up flush right.
  - Score shows the value + `N users` line beneath it (from `num_scoring_users`).
- Centered title, meta line (`TV · 2024 · Finished · 25 ep · 23 min`), blue genre chips with `·` separators.
- **Synopsis** — collapsed to 5 lines with chevron toggle (`AnimatedCrossFade`). Chevron uses a compact `IconButton` (zero padding, 24px min-height) so the gap to the next section is small.
- **Information section** (below synopsis): horizontal divider above, centered "Information" heading, then `Label: value` rows. Shows the first 4 entries with a chevron to expand the rest. Order (skipping any field the API didn't return):
  1. English title (`alternative_titles.en`)
  2. Japanese title (`alternative_titles.ja`)
  3. Synonyms (`alternative_titles.synonyms`, comma-joined)
  4. Aired (`start_date` → `end_date`, formatted as `Jan 12, 2024 to Mar 30, 2024`)
  5. Studios
  6. Source (snake_case → Title Case)
  7. Rating (mapped from MAL codes: `r` → `R - 17+ (violence & profanity)`, etc.)

  **Intentionally excluded**: type / year / status / episode count / episode duration / genres — already shown in the meta line above. **Not available via API**: Producers, Licensors, Themes (MAL-web-only — would need scraping).
- **Related section** (below Information): same divider + centered "Related" heading. Each row: 50×70 thumbnail + title + `relation_type_formatted` (e.g. "Sequel", "Side story", "Full story", "Adaptation"). Tap → push another `AnimeDetailPage` for that anime. First 4 shown, chevron reveals the rest.
- All section chevrons share the same compact style so spacing between sections is tight and consistent.
- AppBar shows heart and share icons as **stubs** (no logic wired). Heart needs OAuth write to toggle favorites; share needs `share_plus` package.
- **No Favorites count**: MAL API doesn't expose `num_favorites`. Could be scraped from the web profile later.

### Search page (`AnimeSearchPage`)
Triggered by the search icon in the AppBar (visible only on the Anime tab — `_index == 3`).
- Focused TextField in the AppBar; clear button (X) when non-empty.
- 350ms debounce, requires ≥3 chars before firing.
- Hits `MalApi.searchAnime(q, limit: 30)`. Taps into `AnimeDetailPage`.

### AppBar avatar (`HomeShell`)
Top-left circle. Three visual states:
- not signed in → grey circle with `Icons.person_outline`
- signing in → spinner
- signed in → user's MAL avatar (from `/v2/users/@me`)

Tap behavior:
- not signed in → kicks off the PKCE flow (`MalAuth.signIn`)
- signed in → push `ProfilePage`

Avatar URL is re-fetched on `initState` and after returning from `ProfilePage` (so sign-out from inside Profile clears the avatar).

### Profile page (`ProfilePage`)
Modeled on the MAL mobile app's profile screen:
- Large rectangular avatar (130×180) + username + joined date / birthday / location
- Anime stats row: Days, Completed, Mean Score
- Status distribution bar (green=watching, blue=completed, yellow=on-hold, red=dropped, grey=plan-to-watch)
- Anime List Entries count
- Sign-out button in the AppBar

**Manga stats are intentionally absent** — MAL's API does not expose them. Only via scraping or a future API revision.

### Other tabs
Home / Movies / TV / Schedule are `_PlaceholderPage` centered-text stubs.

## Known shortcuts / things to revisit

- **No refresh-token flow** — expired tokens force re-login. Add a refresh helper in `MalAuth` that retries 401s.
- **Writes not wired up** — OAuth login works but no PATCH/PUT calls to `/v2/anime/{id}/my_list_status` yet, so the app can't update progress or scores. The detail page's heart and the absent edit-FAB both depend on this.
- **Username still hardcoded** in `config.dart` for the Anime tab list query — even when signed in, we don't call `/v2/users/@me/animelist`. Once OAuth is required, swap to `@me` and drop `malUsername`.
- `Image.network` everywhere with no caching → consider `cached_network_image` once the list grows.
- No list refresh action — cache is per-process. Add a refresh button to `_ListHeader` if data freshness matters.
- Detail page **Favorites** is omitted (API doesn't expose `num_favorites`). Would need profile-page scraping.
- Search page has **no filters** (genre/type/year/rating) — MAL search supports a few via the API, and many more only via the web UI. Add as the use case demands.
- **Manga stats** require scraping (not in API). Profile page notes this in the UI.

## Local toolchain notes

- Android SDK at `~/Android/Sdk` (set `ANDROID_HOME` if running from a fresh shell).
- `cmdline-tools/latest` was installed manually after Android Studio's first-run wizard hit a transient `dl.google.com` timeout.
- Java for Gradle: `~/development/android-studio/jbr` (Android Studio's bundled JBR). Set `JAVA_HOME` to that when running `flutter` outside Android Studio.
