# Python TMDB Test Script

## test_tmdb.py

Simple Python script to call TMDB API and save raw JSON responses to files.

### Prerequisites

1. Install Python 3 (usually pre-installed on Linux)
2. Install requests library:
   ```bash
   pip install requests
   ```
   Or:
   ```bash
   pip3 install requests
   ```

3. Make sure you have a `.env` file in the project root with your TMDB API key:
   ```
   TMDB_API_KEY=your_actual_api_key_here
   TMDB_BASE_URL=https://api.themoviedb.org/3
   ```

### Usage

Run the script:
```bash
python3 scripts/test_tmdb.py
```

Or make it executable and run directly:
```bash
chmod +x scripts/test_tmdb.py
./scripts/test_tmdb.py
```

### Output

The script saves raw JSON responses to `test_responses/` directory:
- `movie_603_matrix_raw.json` - The Matrix full details
- `tv_1396_breaking_bad_raw.json` - Breaking Bad full details
- `tv_2734_law_order_svu_raw.json` - Law & Order: SVU full details
- `tv_66732_stranger_things_raw.json` - Stranger Things full details
- `popular_movies_raw.json` - Popular movies list
- `popular_tv_raw.json` - Popular TV shows list

### What to Look For

Open the JSON files to see:
- `images.logos[]` - Logo array with file_path
- `backdrop_path` - Hero background
- `poster_path` - Poster image
- `overview` - Description
- `genres[]` - Genres
- `vote_average` - Rating
- All other TMDB fields


