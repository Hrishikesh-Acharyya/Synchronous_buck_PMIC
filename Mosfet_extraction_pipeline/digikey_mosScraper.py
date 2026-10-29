import os
import time
import requests
import pandas as pd
from dotenv import load_dotenv

# --- Secure Configuration ---
load_dotenv()
CLIENT_ID = os.getenv("DIGIKEY_CLIENT_ID")
CLIENT_SECRET = os.getenv("DIGIKEY_CLIENT_SECRET")

OUTPUT_EXCEL = "excel_sheets/mosfet_urls.xlsx"
DOWNLOAD_FOLDER = "./datasheets"

# --- Expanded Search Space (Hand-Solderable + Reflow 5x6mm Packages) ---
# Each distinct string gets its own 300-item retrieval window
SEARCH_QUERIES = [
    "N-Channel MOSFET 30V SOIC-8 SMD",
    "N-Channel MOSFET 40V SOIC-8 SMD",
    "N-Channel MOSFET 40V DPAK SMD",
    "N-Channel MOSFET 40V PowerPAK 5x6 SMD",
    "N-Channel MOSFET 40V LFPAK56 SMD",
    "N-Channel MOSFET 60V SOIC-8 SMD",
    "N-Channel MOSFET 60V DPAK SMD",
    "N-Channel MOSFET 60V PowerPAK 5x6 SMD"
]

TOKEN_URL = "https://api.digikey.com/v1/oauth2/token"
SEARCH_URL = "https://api.digikey.com/products/v4/search/keyword"

def setup_environment():
    if not os.path.exists(DOWNLOAD_FOLDER):
        os.makedirs(DOWNLOAD_FOLDER)

def get_access_token():
    print("Authenticating with Digi-Key OAuth2...")
    payload = {
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'grant_type': 'client_credentials'
    }
    response = requests.post(TOKEN_URL, data=payload)
    if response.status_code == 200:
        print("Successfully acquired Access Token.")
        return response.json().get('access_token')
    else:
        print(f"Auth Failed: {response.status_code} - {response.text}")
        return None

def fetch_digikey_data(access_token, keyword, offset):
    """Hits the API for a specific page of 50 results using a sliced keyword."""
    headers = {
        "Authorization": f"Bearer {access_token}",
        "X-DIGIKEY-Client-Id": CLIENT_ID,
        "X-DIGIKEY-Locale-Site": "US",
        "X-DIGIKEY-Locale-Language": "en",
        "X-DIGIKEY-Locale-Currency": "USD",
        "Content-Type": "application/json"
    }
    
    payload = {
        "Keywords": keyword,
        "Limit": 50,
        "Offset": offset
    }
    
    response = requests.post(SEARCH_URL, json=payload, headers=headers)
    if response.status_code == 200:
        return response.json().get("Products", [])
    else:
        print(f"API Error {response.status_code}: {response.text}")
        return []

def scrape_segmented_inventory(access_token):
    """Loops through all defined query segments."""
    all_parts = []
    for query in SEARCH_QUERIES:
        print(f"\n--- Slicing Space: '{query}' ---")
        
        for current_offset in range(0, 300, 50):
            print(f"  Fetching records {current_offset} to {current_offset + 50}...")
            parts = fetch_digikey_data(access_token, query, current_offset)
            
            if not parts:
                print("  No more parts found for this partition. Moving on.")
                break
                
            all_parts.extend(parts)
            time.sleep(1.5) # Protect API limits
            
    return all_parts

def parse_parametric_data(part):
    """Extracts critical technical metrics from the API's parameters list."""
    parameters = part.get("Parameters", [])
    
    # Defaults if the parameters are missing
    v_rating = "Unknown"
    package_case = "Unknown"
    rds_on = "Unknown"
    gate_charge = "Unknown"
    current_drain = "Unknown"
    
    for p in parameters:
        p_name = str(p.get("Parameter", "")).lower()
        p_val = str(p.get("Value", ""))
        
        if "voltage - drain to source" in p_name or "vdss" in p_name:
            v_rating = p_val
        elif "package / case" in p_name:
            package_case = p_val
        elif "rds on" in p_name:
            rds_on = p_val
        elif "gate charge" in p_name or "qg " in p_name:
            gate_charge = p_val
        elif "current - continuous drain" in p_name:
            current_drain = p_val
            
    return v_rating, package_case, rds_on, gate_charge, current_drain

def process_and_save(parts_list):
    extracted_data = []
    print("\nProcessing raw payload and extracting parameters...")
    
    for part in parts_list:
        part_num = part.get("ManufacturerProductNumber", "Unknown")
        url = part.get("DatasheetUrl", "")
        manufacturer = part.get("Manufacturer", {}).get("Value", "Unknown")
        description = part.get("ProductDescription", "Unknown")
        
        # Pull nested specifications
        v_rating, package_case, rds_on, gate_charge, current_drain = parse_parametric_data(part)
        
        if url and url.lower().endswith('.pdf'):
            extracted_data.append({
                "Part_Number": part_num,
                "Manufacturer": manufacturer,
                "Voltage_Rating": v_rating,
                "Package_Case": package_case,
                "Rds_On_Max": rds_on,
                "Gate_Charge_Qg": gate_charge,
                "Continuous_Current": current_drain,
                "Description": description,
                "Datasheet_URL": url
            })
            
    df = pd.DataFrame(extracted_data)
    df = df.drop_duplicates(subset=['Part_Number']) 
    df.to_excel(OUTPUT_EXCEL, index=False)
    print(f"\nMatrix Assembly Complete: Saved {len(df)} unique records with parameters to {OUTPUT_EXCEL}")
    return df

def download_pdfs(df):
    print("\nStarting Automated PDF Download Queue...")
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    
    for index, row in df.iterrows():
        part_num = row["Part_Number"]
        url = row["Datasheet_URL"]
        
        safe_name = "".join(c for c in part_num if c.isalnum() or c in ('-', '_')).rstrip()
        file_path = os.path.join(DOWNLOAD_FOLDER, f"{safe_name}.pdf")
        
        if os.path.exists(file_path):
            print(f"[{index+1}/{len(df)}] Skipping {safe_name}.pdf (Local file match found)")
            continue
            
        try:
            print(f"[{index+1}/{len(df)}] Downloading {safe_name}...")
            response = requests.get(url, headers=headers, stream=True, timeout=10)
            
            if response.status_code == 200:
                with open(file_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
            else:
                print(f"  -> Download Failed: HTTP {response.status_code}")
        except Exception as e:
            print(f"  -> Connection error on part {safe_name}: {e}")
            
        time.sleep(2) # Protect manufacturer CDN infrastructure

if __name__ == "__main__":
    setup_environment()
    
    if os.path.exists(OUTPUT_EXCEL):
        print(f"Local Excel tracking matched: {OUTPUT_EXCEL}")
        mosfet_df = pd.read_excel(OUTPUT_EXCEL)
        download_pdfs(mosfet_df)
    else:
        print("Local tracking database missing. Initiating upstream query...")
        token = get_access_token()
        if token:
            raw_parts = scrape_segmented_inventory(token)
            if raw_parts:
                mosfet_df = process_and_save(raw_parts)
                download_pdfs(mosfet_df)