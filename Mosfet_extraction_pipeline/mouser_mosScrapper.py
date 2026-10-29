import os
import time
import requests
import pandas as pd
from dotenv import load_dotenv

# --- Secure Configuration ---
load_dotenv()
MOUSER_API_KEY = os.getenv("MOUSER_SEARCH_API_KEY")

OUTPUT_EXCEL = "excel_sheets/mosfet_urls.xlsx"
DOWNLOAD_FOLDER = "./datasheets"

# --- Expanded Search Space ---
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

# Mouser Search API v2 Endpoint
MOUSER_SEARCH_URL = "https://api.mouser.com/api/v2/search/keyword"

def load_existing_database():
    """Loads the existing Digi-Key matrix to prevent duplicate scraping."""
    if os.path.exists(OUTPUT_EXCEL):
        df = pd.read_excel(OUTPUT_EXCEL)
        # Create a fast lookup set of all existing part numbers
        existing_parts = set(df['Part_Number'].dropna().astype(str).tolist())
        print(f"Loaded existing database: {len(existing_parts)} unique parts found.")
        return df, existing_parts
    else:
        print("No existing Excel database found. Starting fresh.")
        # If no sheet exists, return an empty DataFrame with the correct columns
        columns = ["Part_Number", "Manufacturer", "Voltage_Rating", "Package_Case", 
                   "Rds_On_Max", "Gate_Charge_Qg", "Continuous_Current", "Description", "Datasheet_URL"]
        return pd.DataFrame(columns=columns), set()

def fetch_mouser_data(keyword, offset):
    """Hits the Mouser API for a specific page of results."""
    # Mouser passes the API key in the query string
    url_with_key = f"{MOUSER_SEARCH_URL}?apiKey={MOUSER_API_KEY}"
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    # Mouser API v2 Payload Structure
    payload = {
        "SearchByKeywordRequest": {
            "keyword": keyword,
            "records": 50,
            "startingRecord": offset,
            "searchOptions": "",
            "searchWithYourSignUpLanguage": ""
        }
    }
    
    try:
        response = requests.post(url_with_key, json=payload, headers=headers)
        if response.status_code == 200:
            data = response.json()
            # Navigate Mouser's specific JSON structure
            return data.get("SearchResults", {}).get("Parts", [])
        else:
            print(f"Mouser API Error {response.status_code}: {response.text}")
            return []
    except Exception as e:
        print(f"Connection Error: {e}")
        return []

def parse_mouser_attributes(attributes):
    """Maps Mouser's dynamic attribute array to our standard column format."""
    v_rating = "Unknown"
    package_case = "Unknown"
    rds_on = "Unknown"
    gate_charge = "Unknown"
    current_drain = "Unknown"
    
    for attr in attributes:
        name = str(attr.get("AttributeName", "")).lower()
        val = str(attr.get("AttributeValue", ""))
        
        if "drain-source breakdown voltage" in name or "vdss" in name:
            v_rating = val
        elif "package / case" in name or "mounting style" in name:
            # Mouser often splits package data, we grab what we can
            if package_case == "Unknown": package_case = val
            else: package_case += f" / {val}"
        elif "rds on" in name or "drain-source on resistance" in name:
            rds_on = val
        elif "gate charge" in name or "qg" in name:
            gate_charge = val
        elif "continuous drain current" in name:
            current_drain = val
            
    return v_rating, package_case, rds_on, gate_charge, current_drain

def scrape_mouser_inventory(existing_parts_set):
    """Loops through all queries and cross-references against the existing set."""
    new_parts_data = []
    total_mouser_hits = 0
    
    for query in SEARCH_QUERIES:
        print(f"\n--- Slicing Mouser Space: '{query}' ---")
        
        # Mouser allows deep pagination, but we will stick to top 1000 for relevance
        for current_offset in range(0, 1000, 50):
            print(f"  Fetching records {current_offset} to {current_offset + 50}...")
            parts = fetch_mouser_data(query, current_offset)
            
            if not parts:
                print("  No more parts found for this partition. Moving on.")
                break
                
            for part in parts:
                part_num = part.get("ManufacturerPartNumber", "Unknown")
                total_mouser_hits += 1
                
                # --- THE STRICT DEDUPLICATION GATE ---
                if part_num in existing_parts_set:
                    continue # Skip it, we already got it from Digi-Key
                
                url = part.get("DataSheetUrl", "")
                # Ensure the URL is valid and looks like a PDF
                if url and "pdf" in url.lower():
                    manufacturer = part.get("Manufacturer", "Unknown")
                    description = part.get("Description", "Unknown")
                    
                    attributes = part.get("ProductAttributes", [])
                    v_rating, package_case, rds_on, gate_charge, current_drain = parse_mouser_attributes(attributes)
                    
                    new_parts_data.append({
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
                    
                    # Add to our fast lookup set so we don't duplicate within the Mouser pull itself
                    existing_parts_set.add(part_num)
            
            # Mouser's API rate limit is usually 30 calls per minute
            time.sleep(2.5) 
            
    print(f"\nScrape Complete. Analyzed {total_mouser_hits} total parts.")
    return new_parts_data

def download_new_pdfs(new_df):
    if new_df.empty:
        print("No new PDFs to download.")
        return
        
    print(f"\nStarting Download Queue for {len(new_df)} NEW parts...")
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    
    for index, row in new_df.iterrows():
        part_num = row["Part_Number"]
        url = row["Datasheet_URL"]
        
        safe_name = "".join(c for c in part_num if c.isalnum() or c in ('-', '_')).rstrip()
        file_path = os.path.join(DOWNLOAD_FOLDER, f"{safe_name}.pdf")
        
        if os.path.exists(file_path):
            continue
            
        try:
            print(f"[{index+1}/{len(new_df)}] Downloading Mouser addition: {safe_name}...")
            response = requests.get(url, headers=headers, stream=True, timeout=15)
            
            if response.status_code == 200:
                with open(file_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
            else:
                print(f"  -> Download Failed: HTTP {response.status_code}")
        except Exception as e:
            print(f"  -> Connection error on part {safe_name}: {e}")
            
        time.sleep(2)

if __name__ == "__main__":
    if not os.path.exists(DOWNLOAD_FOLDER):
        os.makedirs(DOWNLOAD_FOLDER)
        
    print("Initializing Unified Matrix Expansion...")
    existing_df, existing_parts_set = load_existing_database()
    
    if MOUSER_API_KEY:
        new_raw_data = scrape_mouser_inventory(existing_parts_set)
        
        if new_raw_data:
            # Create a DataFrame of JUST the new Mouser components
            new_df = pd.DataFrame(new_raw_data)
            
            # Append the new parts to the bottom of the existing Digi-Key DataFrame
            combined_df = pd.concat([existing_df, new_df], ignore_index=True)
            
            # Save the unified dataset back to the Excel file
            combined_df.to_excel(OUTPUT_EXCEL, index=False)
            print(f"\nSuccessfully appended {len(new_df)} unique Mouser parts.")
            print(f"Master Matrix now contains {len(combined_df)} total components.")
            
            # Trigger the downloader only for the newly discovered parts
            download_new_pdfs(new_df)
        else:
            print("No novel components discovered on Mouser. The matrix is already comprehensive.")
    else:
        print("ERROR: MOUSER_API_KEY missing from environment configuration.")