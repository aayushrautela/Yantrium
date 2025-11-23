# Environment Setup

This application requires a TMDB (The Movie Database) API key to fetch metadata for movies and TV shows.

## Setup Instructions

1. **Get a TMDB API Key:**
   - Go to https://www.themoviedb.org/
   - Create an account or log in
   - Navigate to Settings > API
   - Request an API key (it's free)
   - Copy your API key

2. **Create `.env` file:**
   - Copy `.env.example` to `.env` in the project root:
     ```bash
     cp .env.example .env
     ```
   
   - Or create `.env` manually with the following content:
     ```
     TMDB_API_KEY=your_actual_api_key_here
     TMDB_BASE_URL=https://api.themoviedb.org/3
     TMDB_IMAGE_BASE_URL=https://image.tmdb.org/t/p
     ```

3. **Replace the placeholder:**
   - Open `.env` file
   - Replace `your_actual_api_key_here` with your actual TMDB API key

## How It Works

- All metadata (posters, descriptions, ratings, etc.) is fetched from TMDB
- Addons only provide content IDs (like `tmdb:123` or `tt1234567`)
- The app automatically enriches catalog items with TMDB metadata
- If TMDB lookup fails, the app falls back to the original addon metadata

## Supported ID Formats

The app supports multiple content ID formats:
- `tmdb:123` - Direct TMDB ID
- `tt1234567` - IMDB ID (will be converted to TMDB ID)
- `123` - Numeric string (assumed to be TMDB ID)


