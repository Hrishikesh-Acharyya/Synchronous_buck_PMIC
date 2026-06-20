import os
from google import genai
from dotenv import load_dotenv

load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    print("ERROR: API key not found in .env file.")
    exit()

client = genai.Client(api_key=API_KEY)

print("Querying Google's servers for available Flash models...")
try:
    models = client.models.list()
    found_flash = False
    for model in models:
        # We only care about the fast, cheap 'flash' models for this pipeline
        if "flash" in model.name.lower():
            print(f" ✅ {model.name}")
            found_flash = True
            
    if not found_flash:
        print(" ❌ No models with 'flash' in the name are available to this API key.")
        
except Exception as e:
    print(f"API Error: {e}")