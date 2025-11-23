# Running the TMDB Test Script

## Quick Start

1. Make sure you have a `.env` file with your TMDB API key:
   ```bash
   TMDB_API_KEY=your_actual_api_key_here
   ```

2. Run the test script:
   ```bash
   dart run scripts/test_tmdb.dart
   ```

3. Check the `test_responses/` directory for JSON files with API responses.

## What the Script Tests

The script makes 8 different TMDB API calls:

1. **Popular Movies** - `/movie/popular`
2. **Movie Details** - `/movie/603` (The Matrix) with videos, credits, images
3. **Popular TV Shows** - `/tv/popular`
4. **TV Show Details** - `/tv/1396` (Breaking Bad) with videos, credits, images
5. **IMDB to TMDB Lookup** - `/find/tt0133093` (The Matrix)
6. **IMDB to TMDB Lookup** - `/find/tt0903747` (Breaking Bad)
7. **Movie Search** - `/search/movie?query=Matrix`
8. **TV Search** - `/search/tv?query=Breaking Bad`

## Analyzing the Responses

Each JSON file contains the full API response. You can:
- Open them in any text editor
- Use a JSON viewer/formatter
- Compare with the TMDB API documentation
- Debug any issues with data structure

## Troubleshooting

If you get errors:
- Check that `.env` file exists and has a valid API key
- Verify your API key is active at https://www.themoviedb.org/settings/api
- Check your internet connection
- Review the error messages in the console output


