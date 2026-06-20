import os
import time
import json
import pandas as pd
from typing import Optional
from pydantic import BaseModel, Field
from google import genai
from google.genai import types
from dotenv import load_dotenv

# --- Configuration ---
load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY_MOSFET_SCRAPPER_2")

MASTER_EXCEL = "mosfet_urls.xlsx"
DOWNLOAD_FOLDER = "./datasheets"

if not API_KEY:
    raise ValueError("GEMINI_API_KEY is missing from your .env file!")

# Initialize the new Google GenAI Client
client = genai.Client(api_key=API_KEY)

# --- The Honest Data Schema ---
class MosfetSpecifications(BaseModel):
    Manufacturer: str = Field(description="The name of the component manufacturer.")
    Part_Number: str = Field(description="The exact Manufacturer Part Number (MPN).")
    Package_Case: str = Field(description="The physical package style (e.g., SOIC-8, DPAK, LFPAK56).")
    
    V_dss_Volts: float = Field(description="Maximum Drain-to-Source Breakdown Voltage (Vdss) in Volts.")
    Id_continuous_Amps: float = Field(description="Maximum Continuous Drain Current (Id) at 25°C in Amperes.")
    Logic_Level: str = Field(description="Return 'Yes' if described as logic-level OR if Absolute Max Vgs is strictly less than 20V (e.g., 8V, 12V). Otherwise 'No'.")
    Max_Vgs_Rating_Volts: Optional[float] = Field(description="Absolute Maximum Gate-Source Voltage rating. Only populate if Logic_Level is 'Yes', else return null.")
    
    Test_Vgs_Volts: float = Field(description="The exact gate drive test voltage (Vgs) at which Rds(on) and Qg were extracted (e.g., 10.0 or 4.5).")
    Rds_on_max_mOhm: float = Field(description="Maximum Static Drain-Source On-Resistance (Rds(on)) at the specified Test_Vgs_Volts in milliohms (mΩ).")
    
    Qg_total_nC: float = Field(description="Total Gate Charge (Qg) typical value in nanocoulombs (nC).")
    Qgd_gate_drain_nC: float = Field(description="Gate-to-Drain 'Miller' Charge (Qgd) typical value in nC.")
    
    Qgs_total_nC: Optional[float] = Field(description="Total Gate-to-Source charge (Qgs). If the datasheet breaks it into pre/post (Qgs1/Qgs2) and does NOT provide a total, return null.")
    Qgs1_pre_thresh_nC: Optional[float] = Field(description="Pre-threshold charge (Qgs1). If the datasheet ONLY gives total Qgs, return null. Do not fake this data.")
    Qgs2_post_thresh_nC: Optional[float] = Field(description="Post-threshold charge (Qgs2). If the datasheet ONLY gives total Qgs, return null. Do not fake this data.")
    
    Qsw_switching_nC: float = Field(description="Switching charge (Qsw). If not explicitly listed, calculate using fallback math.")
    Qg_Qsw_ratio: float = Field(description="The calculated ratio of Total Gate Charge (Qg) divided by Switching Charge (Qsw).")
    
    Vsd_body_diode_Volts: float = Field(description="Source-Drain Diode Forward Voltage maximum value in Volts.")

# --- THE ULTIMATE EXPERT PROMPT ---
GEMINI_PROMPT = """
You are a highly precise power electronics engineer. Analyze this MOSFET datasheet and extract the exact specifications requested.

CRITICAL RULES FOR DATA SINCERITY & MANUFACTURER QUIRKS:
1. Qgs Honesty & Nomenclature: DO NOT assume or fake data placement. Foundries use different names.
   - Pre-threshold (Qgs1) aliases: 'Qgs1', 'Qgs(th)', 'Qg(th)'.
   - Post-threshold (Qgs2) aliases: 'Qgs2', 'Qgs(th-pl)'.
   - If the table explicitly prints a single total 'Qgs' (Gate-to-Source Charge), put it in `Qgs_total_nC` and leave `Qgs1` and `Qgs2` as null. 
   - If the table explicitly prints the split (Qgs1/Qgs2 or equivalents), put them in their respective fields, and leave `Qgs_total_nC` as null (unless a total is also provided).
2. The 10V Rule, Test Conditions & Aliases: You must identify the Vgs used for the Rds(on) (sometimes labeled 'Ron') test. Alpha & Omega and ON Semi often list 4.5V and 10V conditions side-by-side. Prioritize extracting Rds(on) and Qg specifically at Vgs = 10V. If 10V is not available, use the highest available (e.g., 4.5V). Record this exact test voltage in `Test_Vgs_Volts`.
3. Logic Level Safety: Check the 'Absolute Maximum Ratings' table. If the max Vgs rating is strictly less than 20V (e.g., ±8V or ±12V), OR if the description explicitly states "Logic-Level", set `Logic_Level` to 'Yes' and extract that maximum voltage into `Max_Vgs_Rating_Volts`. Otherwise, set it to 'No' and leave the max voltage null.
4. Qsw Calculation Hierarchy:
   - Priority 1: If 'Qsw' or 'Switching Charge' is explicitly printed, use it.
   - Priority 2: If Qsw is missing but Qgs2 (or Qgs(th-pl)) is provided: Qsw = Qgs2 + Qgd.
   - Priority 3: If only total Qgs is provided: Qsw = (0.5 * Qgs) + Qgd.
5. Units & The Ohm Trap: Convert ALL resistance values to milliohms (mΩ). (e.g., if Infineon/Microchip lists 0.0075 Ω, you MUST extract it as 7.5). Return pure floating point numbers.
6. Diode Nomenclature: Look for 'Diode Forward Voltage', 'Source-Drain Voltage', 'VSD'. For Renesas, look for 'VF(S-D)'. For Toshiba, look for 'VDSF'. Extract the maximum or typical value.
"""

def process_datasheet(file_path):
    max_retries = 3
    base_wait_time = 60 # Wait 60 seconds if we hit a rate limit
    
    for attempt in range(max_retries):
        try:
            # Upload via the new SDK
            datasheet_file = client.files.upload(file=file_path, config={'mime_type': 'application/pdf'})
            
            # Wait for backend processing if necessary
            file_info = client.files.get(name=datasheet_file.name)
            while file_info.state.name == "PROCESSING":
                time.sleep(2)
                file_info = client.files.get(name=datasheet_file.name)
                
            # Call the model using the stable 1.5-flash-002 endpoint
            response = client.models.generate_content(
                model='gemini-flash-latest',
                contents=[datasheet_file, GEMINI_PROMPT],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=MosfetSpecifications,
                    temperature=0.0
                )
            )
            
            # Clean up Google's servers to prevent storage bloat
            client.files.delete(name=datasheet_file.name)
            return json.loads(response.text)
            
        except Exception as e:
            error_message = str(e)
            # If the file uploaded successfully before the crash, try to delete it so we don't leak storage
            try:
                client.files.delete(name=datasheet_file.name)
            except:
                pass
                
            if "429" in error_message or "RESOURCE_EXHAUSTED" in error_message:
                print(f"  ⚠️ Rate limit hit. Pausing extraction for {base_wait_time} seconds (Attempt {attempt + 1}/{max_retries})...")
                time.sleep(base_wait_time)
                # Increase the wait time for the next attempt just in case
                base_wait_time *= 2 
            else:
                print(f"  ❌ Fatal Error processing PDF: {error_message}")
                return None
                
    print("  ❌ Max retries exceeded due to rate limits. Skipping this component.")
    return None

def run_extraction_pipeline():
    print(f"Loading Master Matrix: {MASTER_EXCEL}")
    df = pd.read_excel(MASTER_EXCEL)
    
    target_columns = list(MosfetSpecifications.model_fields.keys())
    for col in target_columns:
        if col not in df.columns:
            df[col] = pd.NA
            
    total_rows = len(df)
    processed_count = 0
    
    print("Beginning Deep Extraction Loop...")
    for index, row in df.iterrows():
        part_num = str(row['Part_Number'])
        
        if pd.notna(row.get('Test_Vgs_Volts')) and str(row.get('Test_Vgs_Volts')).strip() != "":
            continue
            
        safe_name = "".join(c for c in part_num if c.isalnum() or c in ('-', '_')).rstrip()
        file_path = os.path.join(DOWNLOAD_FOLDER, f"{safe_name}.pdf")
        
        if not os.path.exists(file_path):
            print(f"[{index+1}/{total_rows}] ⚠️ PDF missing for {part_num}. Skipping.")
            continue
            
        print(f"[{index+1}/{total_rows}] Analyzing {part_num}...")
        extracted_data = process_datasheet(file_path)
        
        if extracted_data:
            for key, value in extracted_data.items():
                df.at[index, key] = value
                
            processed_count += 1
            is_logic = extracted_data.get('Logic_Level')
            test_v = extracted_data.get('Test_Vgs_Volts')
            print(f"  -> Success: Logic Level={is_logic} | Test Vgs={test_v}V | Rds(on)={extracted_data.get('Rds_on_max_mOhm')}mΩ")
            
            if processed_count % 5 == 0:
                df.to_excel(MASTER_EXCEL, index=False)
                
        time.sleep(5) 
        
    df.to_excel(MASTER_EXCEL, index=False)
    print("\n Extraction Pipeline Complete! Master Excel file updated.")

if __name__ == "__main__":
    run_extraction_pipeline()