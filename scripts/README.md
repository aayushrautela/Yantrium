# Test Scripts

## test_tmdb_detailed.dart

Test script to call TMDB API and save detailed responses with full metadata including logos, images, and all available data.

### Usage

```bash
dart run scripts/test_tmdb_detailed.dart
```

### What It Tests

The script fetches detailed information for:
1. **The Matrix (Movie ID: 603)** - Full movie details with images
2. **Breaking Bad (TV ID: 1396)** - Full TV show details with images
3. **Law & Order: SVU (TV ID: 2734)** - With separate logo extraction
4. **Dune: Part Two (Movie ID: 693134)** - Recent movie
5. **Stranger Things (TV ID: 66732)** - Popular series

### Output

All responses are saved to `test_responses/` directory with full JSON data including:
- `images.logos[]` - Logo images array
- `backdrop_path` - Hero background image
- `poster_path` - Poster image
- `overview` - Description
- `genres[]` - Genres array
- `credits` - Cast and crew
- `videos` - Trailers and videos

### Analyzing Responses

Open the JSON files to see:
- Logo structure and file paths
- Image sizes and formats available
- All metadata fields from TMDB
- How to parse the data for your app

## test_tmdb.dart

Original test script to call TMDB API and save responses to files for analysis.

### Prerequisites

1. Make sure you have a `.env` file in the project root with your TMDB API key:
   ```
   TMDB_API_KEY=your_actual_api_key_here
   TMDB_BASE_URL=https://api.themoviedb.org/3
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

### Usage

Run the script:
```bash
dart run scripts/test_tmdb.dart
```

Or if you're in the scripts directory:
```bash
dart run ../scripts/test_tmdb.dart
```

### Output

The script will create a `test_responses/` directory with JSON files containing:
- `popular_movies.json` - Popular movies list
- `movie_603_matrix.json` - The Matrix movie details
- `popular_tv.json` - Popular TV shows list
- `tv_1396_breaking_bad.json` - Breaking Bad TV show details
- `find_imdb_tt0133093.json` - IMDB to TMDB ID lookup for The Matrix
- `find_imdb_tt0903747.json` - IMDB to TMDB ID lookup for Breaking Bad
- `search_movie_matrix.json` - Movie search results
- `search_tv_breaking_bad.json` - TV search results

### Analyzing Responses

You can open these JSON files in any text editor or JSON viewer to:
- Check the structure of TMDB responses
- Verify API key is working
- Understand the data format for integration
- Debug any issues with metadata fetching

