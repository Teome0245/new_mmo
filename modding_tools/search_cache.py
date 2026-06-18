import json
import sys

def main():
    cache_path = "/home/sdesh/projects/new_mmo/modding_tools/patch_fr_workspace/translation_cache.json"
    with open(cache_path, "r", encoding="utf-8") as f:
        cache = json.load(f)
    
    search_terms = ["Select a Character", "Available Characters", "cannot connect to that Galaxy", "Delete", "Create", "Exit", "Next"]
    if len(sys.argv) > 1:
        search_terms = sys.argv[1:]
        
    for term in search_terms:
        print(f"--- Searching for: '{term}' ---")
        found = False
        for k, v in cache.items():
            if term.lower() in k.lower():
                print(f"Key:   {repr(k)}")
                print(f"Value: {repr(v)}")
                found = True
        if not found:
            print("Not found in cache.")

if __name__ == "__main__":
    main()
