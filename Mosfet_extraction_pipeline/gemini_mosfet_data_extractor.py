import os
import time
import json
import pandas as pd
from typing import Optional
from pydantic import BaseModel, Field
from google import genai
from google.genai import types
from dotenv import load_dotenv

# --- Configuration & Initialization ---
load_dotenv()

MASTER_EXCEL = "mosfet_urls.xlsx"
DOWNLOAD_FOLDER = "datasheets"

# 1. Gather all available API keys for the rotation engine
API_KEYS = []
for i in range(31, 42):  # Adjust the range as needed
    key_name = f"GEMINI_API_KEY_MOSFET_SCRAPPER_{i}" if i >= 3 else "GEMINI_API_KEY"
    key = os.getenv(key_name)
    if key:
        API_KEYS.append(key)

if not API_KEYS:
    raise ValueError("ERROR: No valid GEMINI_API_KEY variables found in your .env configuration!")

print(f"✅ Key Rotation Engine initialized with {len(API_KEYS)} active keys.")
current_key_index = 0

def get_rotated_client():
    """Cycles through the keys sequentially and returns a fresh genai client."""
    global current_key_index
    selected_key = API_KEYS[current_key_index]
    client = genai.Client(api_key=selected_key)
    current_key_index = (current_key_index + 1) % len(API_KEYS)
    return client

# --- The Structured Output Schema ---
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
    
    Qgs_total_nC: Optional[float] = Field(description="Total Gate-to-Source charge (Qgs). If broken into pre/post without a total, return null.")
    Qgs1_pre_thresh_nC: Optional[float] = Field(description="Pre-threshold charge (Qgs1). If ONLY total Qgs is given, return null.")
    Qgs2_post_thresh_nC: Optional[float] = Field(description="Post-threshold charge (Qgs2). If ONLY total Qgs is given, return null.")
    
    Qsw_switching_nC: float = Field(description="Switching charge (Qsw). If not explicitly listed, calculate using fallback math.")
    Qg_Qsw_ratio: float = Field(description="The calculated ratio of Total Gate Charge (Qg) divided by Switching Charge (Qsw).")
    
    Vsd_body_diode_Volts: float = Field(description="Source-Drain Diode Forward Voltage maximum value in Volts.")

# --- The Expert Prompt ---
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

# --- The Main Execution Pipeline ---
def run_extraction_pipeline():
    if not os.path.exists(MASTER_EXCEL):
        raise FileNotFoundError(f"Could not find target master spreadsheet: '{MASTER_EXCEL}'")
        
    df = pd.read_excel(MASTER_EXCEL)
    
    # Ensure all target columns from the schema exist in the DataFrame
    target_columns = list(MosfetSpecifications.model_fields.keys())
    for col in target_columns:
        if col not in df.columns:
            df[col] = pd.NA

    total_rows = len(df)
    print("🚀 Starting deep extraction processing run...")

    for index, row in df.iterrows():
        part_num = str(row['Part_Number']).strip()
        
        # Checkpoint Shield: Skip if we already successfully extracted data for this row
        if pd.notna(row.get('Test_Vgs_Volts')) and str(row.get('Test_Vgs_Volts')).strip() != "":
            continue
            
        print(f"[{index+1}/{total_rows}] Analyzing {part_num}...")
        
        # Build file path
        safe_name = "".join(c for c in part_num if c.isalnum() or c in ('-', '_')).rstrip()
        pdf_path = os.path.join(DOWNLOAD_FOLDER, f"{safe_name}.pdf")
        
        if not os.path.exists(pdf_path):
            print(f"  ⚠️ PDF missing for {part_num}. Skipping.")
            continue
            
        # Get a freshly rotated client to distribute token load
        client = get_rotated_client()
        uploaded_file = None
            
        try:
            # 1. Upload the PDF
            uploaded_file = client.files.upload(file=pdf_path, config={'mime_type': 'application/pdf'})
            
            # 2. Wait for Google's servers to process the document
            file_info = client.files.get(name=uploaded_file.name)
            while file_info.state.name == "PROCESSING":
                time.sleep(2)
                file_info = client.files.get(name=uploaded_file.name)
                
            if file_info.state.name == "FAILED":
                raise Exception("Google file processing failed on server side.")

            # 3. Generate structured content
            response = client.models.generate_content(
                model='gemini-flash-latest',
                contents=[uploaded_file, GEMINI_PROMPT],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=MosfetSpecifications,
                    temperature=0.0
                )
            )
            
            # 4. Map the JSON response directly into the Pandas DataFrame
            extracted_data = json.loads(response.text)
            for key, value in extracted_data.items():
                df.at[index, key] = value
                
            is_logic = extracted_data.get('Logic_Level')
            test_v = extracted_data.get('Test_Vgs_Volts')
            rds_on = extracted_data.get('Rds_on_max_mOhm')
            print(f"  -> Success: Logic={is_logic} | Vgs={test_v}V | Rds(on)={rds_on}mΩ")

        except Exception as e:
            error_msg = str(e)
            if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg:
                print("  ⚠️ Rate limit hit across rotation. Pausing for 60s...")
                time.sleep(60)
            else:
                print(f"  ❌ Error processing {part_num}: {error_msg}")
        finally:
            # Clean up the cloud storage bucket so we don't hit the 20GB limit
            if uploaded_file:
                try:
                    client.files.delete(name=uploaded_file.name)
                except:
                    pass
            
        # 5. IMMEDIATE SAVE PROTOCOL (Runs after every single MOSFET)
        saved = False
        while not saved:
            try:
                df.to_excel(MASTER_EXCEL, index=False)
                saved = True
            except PermissionError:
                print(f"  🚨 ALERT: Cannot write to disk! Close '{MASTER_EXCEL}' immediately. Retrying in 5s...")
                time.sleep(5)

        # Padding between API calls
        time.sleep(1)

    print("\n✅ Extraction Pipeline Complete! All datasheets processed.")

if __name__ == "__main__":
    run_extraction_pipeline()