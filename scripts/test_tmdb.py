#!/usr/bin/env python3
"""
Test script to call TMDB API and save raw responses to files.
Usage: python3 scripts/test_tmdb.py
"""

import os
import json
import requests
from pathlib import Path

# Load environment variables from .env file
def load_env():
    env_file = Path('.env')
    env_vars = {}
    if env_file.exists():
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
    return env_vars

def main():
    # Load environment variables
    env_vars = load_env()
    api_key = env_vars.get('TMDB_API_KEY', '')
    base_url = env_vars.get('TMDB_BASE_URL', 'https://api.themoviedb.org/3')
    
    if not api_key or api_key == 'your_tmdb_api_key_here':
        print('Error: TMDB_API_KEY not set in .env file')
        print('Please set your TMDB API key in the .env file')
        return
    
    # Create output directory
    output_dir = Path('test_responses')
    output_dir.mkdir(exist_ok=True)
    
    print('Testing TMDB API calls...\n')
    
    # Test 1: Get a movie with full details (The Matrix - ID: 603)
    print('1. Fetching movie details (The Matrix - ID: 603)...')
    try:
        url = f'{base_url}/movie/603'
        params = {
            'api_key': api_key,
            'append_to_response': 'videos,credits,images'
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        
        file_path = output_dir / 'movie_603_matrix_raw.json'
        with open(file_path, 'w') as f:
            json.dump(response.json(), f, indent=2)
        print(f'   ✓ Saved to {file_path}')
    except Exception as e:
        print(f'   ✗ Error: {e}')
    
    # Test 2: Get a TV show with full details (Breaking Bad - ID: 1396)
    print('\n2. Fetching TV show details (Breaking Bad - ID: 1396)...')
    try:
        url = f'{base_url}/tv/1396'
        params = {
            'api_key': api_key,
            'append_to_response': 'videos,credits,images'
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        
        file_path = output_dir / 'tv_1396_breaking_bad_raw.json'
        with open(file_path, 'w') as f:
            json.dump(response.json(), f, indent=2)
        print(f'   ✓ Saved to {file_path}')
    except Exception as e:
        print(f'   ✗ Error: {e}')
    
    # Test 3: Get Law & Order: SVU (ID: 2734)
    print('\n3. Fetching Law & Order: SVU (ID: 2734)...')
    try:
        url = f'{base_url}/tv/2734'
        params = {
            'api_key': api_key,
            'append_to_response': 'videos,credits,images'
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        
        file_path = output_dir / 'tv_2734_law_order_svu_raw.json'
        with open(file_path, 'w') as f:
            json.dump(response.json(), f, indent=2)
        print(f'   ✓ Saved to {file_path}')
    except Exception as e:
        print(f'   ✗ Error: {e}')
    
    # Test 4: Get Stranger Things (ID: 66732)
    print('\n4. Fetching Stranger Things (ID: 66732)...')
    try:
        url = f'{base_url}/tv/66732'
        params = {
            'api_key': api_key,
            'append_to_response': 'videos,credits,images'
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        
        file_path = output_dir / 'tv_66732_stranger_things_raw.json'
        with open(file_path, 'w') as f:
            json.dump(response.json(), f, indent=2)
        print(f'   ✓ Saved to {file_path}')
    except Exception as e:
        print(f'   ✗ Error: {e}')
    
    # Test 5: Get popular movies
    print('\n5. Fetching popular movies...')
    try:
        url = f'{base_url}/movie/popular'
        params = {'api_key': api_key}
        response = requests.get(url, params=params)
        response.raise_for_status()
        
        file_path = output_dir / 'popular_movies_raw.json'
        with open(file_path, 'w') as f:
            json.dump(response.json(), f, indent=2)
        print(f'   ✓ Saved to {file_path}')
    except Exception as e:
        print(f'   ✗ Error: {e}')
    
    # Test 6: Get popular TV shows
    print('\n6. Fetching popular TV shows...')
    try:
        url = f'{base_url}/tv/popular'
        params = {'api_key': api_key}
        response = requests.get(url, params=params)
        response.raise_for_status()
        
        file_path = output_dir / 'popular_tv_raw.json'
        with open(file_path, 'w') as f:
            json.dump(response.json(), f, indent=2)
        print(f'   ✓ Saved to {file_path}')
    except Exception as e:
        print(f'   ✗ Error: {e}')
    
    print('\n✓ All tests completed!')
    print(f'Check the {output_dir}/ directory for JSON files.')

if __name__ == '__main__':
    main()


