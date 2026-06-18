#!/usr/bin/env python3
import re
import urllib.parse
import requests
import time

# Match game tokens like %TT, %TO, %DI, and UI formatting tags like \#pcontrast1 and \#.
TOKEN_REGEX = re.compile(r'(%[A-Z]{2}|\\#[a-zA-Z0-9_]+|\\#\.)')

def translate_string(text, target_lang='fr', source_lang='en'):
    if not text or not text.strip():
        return text
    
    # 1. Protect tokens by replacing them with unique placeholders
    tokens = TOKEN_REGEX.findall(text)
    protected_text = text
    placeholders = []
    
    for idx, token in enumerate(tokens):
        placeholder = f"___TK{idx}___"
        placeholders.append((placeholder, token))
        # Replace only the first occurrence at a time to handle duplicates properly
        protected_text = protected_text.replace(token, placeholder, 1)
        
    # 2. Call Google Translate
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={urllib.parse.quote(protected_text)}"
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            translated = "".join([part[0] for part in data[0] if part[0]])
        else:
            print(f"Warning: translation API returned status {response.status_code}")
            translated = text
    except Exception as e:
        print(f"Error during translation request: {e}")
        translated = text
        
    # 3. Restore protected tokens
    for placeholder, original_token in placeholders:
        # Use case-insensitive regex to replace the placeholder
        translated = re.sub(re.escape(placeholder), original_token, translated, flags=re.IGNORECASE)
        
    return translated

# Test the function
if __name__ == "__main__":
    test_cases = [
        'You are attempting to buy a container named "\\#pcontrast1 %TT\\#.".',
        'The Commodities Market requires %DI credits.',
        'Please travel to %TT, on %TO, and access a Market Terminal there.'
    ]
    for tc in test_cases:
        translated = translate_string(tc)
        print(f"Original:   {tc}")
        print(f"Translated: {translated}")
        print("-" * 50)
