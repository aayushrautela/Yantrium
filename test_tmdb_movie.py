#!/usr/bin/env python3
"""
Test script to fetch TMDB movie data and save raw response
"""
import os
import json
import requests

# Get API key from environment variable
api_key = os.getenv('TMDB_API_KEY')
if not api_key:
    # Try reading from .env file directly
    try:
        with open('.env', 'r') as f:
            for line in f:
                if line.startswith('TMDB_API_KEY='):
                    api_key = line.split('=', 1)[1].strip().strip('"').strip("'")
                    break
    except FileNotFoundError:
        pass

if not api_key:
    raise ValueError("TMDB_API_KEY not found. Please set it as environment variable or in .env file")

# TMDB API base URL
base_url = "https://api.themoviedb.org/3"

# Movie ID for Operation Blood Hunt
movie_id = 1084222

# Fetch movie metadata with images
url = f"{base_url}/movie/{movie_id}"
params = {
    'api_key': api_key,
    'append_to_response': 'videos,credits,images',
}

print(f"Fetching movie data for ID: {movie_id}")
print(f"URL: {url}")

response = requests.get(url, params=params)

if response.status_code == 200:
    data = response.json()
    
    # Save raw response to file
    output_file = f"test_responses/movie_{movie_id}_raw.json"
    os.makedirs("test_responses", exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Success! Saved raw response to: {output_file}")
    print(f"Movie title: {data.get('title', 'N/A')}")
    print(f"Release date: {data.get('release_date', 'N/A')}")
    
    # Check for logos
    images = data.get('images', {})
    logos = images.get('logos', [])
    print(f"\nLogos found: {len(logos)}")
    if logos:
        print("First logo details:")
        first_logo = logos[0]
        print(f"  - File path: {first_logo.get('file_path', 'N/A')}")
        print(f"  - Country: {first_logo.get('iso_3166_1', 'N/A')}")
        print(f"  - Language: {first_logo.get('iso_639_1', 'N/A')}")
        print(f"  - Aspect ratio: {first_logo.get('aspect_ratio', 'N/A')}")
        print(f"  - Height: {first_logo.get('height', 'N/A')}")
        print(f"  - Width: {first_logo.get('width', 'N/A')}")
else:
    print(f"❌ Error: {response.status_code}")
    print(f"Response: {response.text}")

