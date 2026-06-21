import pandas as pd
import re

# --- CONFIGURATION ---
input_file = 'mosfet_urls.xlsx'
output_file = 'cleaned_mosfets.xlsx'

# Exact column headers based on your image and list
col_vdss = 'V_dss_Volts' 
col_vgs = 'Max_Vgs_Rating_Volts'
col_id = 'Id_continuous_Amps'
col_package = 'Package_Case'

def extract_number(val):
    if pd.isna(val):
        return 0.0
    match = re.search(r'[\d\.]+', str(val))
    return float(match.group()) if match else 0.0

def evaluate_package(pkg_string):
    if pd.isna(pkg_string):
        return "Unknown Package"
    pkg = str(pkg_string).upper()
    
    if any(x in pkg for x in ['TO-220', 'TO-247', 'TO-264', 'TO-92', 'SIP']):
        return "Through-Hole"
    if any(x in pkg for x in ['BGA', 'WLCSP', 'CSP', '1X1', '2X2']):
        return "Too Small / BGA"
    return "OK"

def main():
    print(f"Loading {input_file}...")
    try:
        df = pd.read_excel(input_file)
    except FileNotFoundError:
        print(f"Error: Could not find {input_file}")
        return

    # 1. Smarter Empty Row Drop
    initial_rows = len(df)
    df.dropna(subset=[col_vdss, col_vgs, col_id], how='all', inplace=True)
    print(f"Dropped {initial_rows - len(df)} rows with missing electrical data.")

    # 2. Extract Data
    df['Vdss_num'] = df[col_vdss].apply(extract_number)
    df['Vgs_num'] = df[col_vgs].apply(extract_number)
    df['Id_num'] = df[col_id].apply(extract_number)

    # 3. Apply Rejection Logic
    def evaluate_mosfet(row):
        reasons = []
        if row['Vdss_num'] < 30:
            reasons.append(f"Low Vdss ({row['Vdss_num']}V < 30V)")
        if row['Vgs_num'] < 18 and row['Vgs_num'] > 0: 
            reasons.append(f"Low Vgs ({row['Vgs_num']}V < 18V)")
        if row['Id_num'] < 7.5:
             reasons.append(f"Low Id ({row['Id_num']}A < 7.5A)")
             
        pkg_status = evaluate_package(row.get(col_package, ""))
        if pkg_status != "OK":
            reasons.append(f"Bad Package ({pkg_status})")
        
        if reasons:
            return 'REJECT: ' + ' | '.join(reasons)
        return 'PASS'

    df['Validation_Status'] = df.apply(evaluate_mosfet, axis=1)
    df.drop(columns=['Vdss_num', 'Vgs_num', 'Id_num'], inplace=True)

    # 4. Highlight
    def highlight_rejects(row):
        if 'REJECT' in str(row['Validation_Status']):
            return ['background-color: #ff9999'] * len(row)
        return [''] * len(row)

    print("Applying validation logic and rendering red highlights...")
    styled_df = df.style.apply(highlight_rejects, axis=1)
    styled_df.to_excel(output_file, index=False, engine='openpyxl')
    
    pass_count = (df['Validation_Status'] == 'PASS').sum()
    reject_count = len(df) - pass_count
    
    print(f"\nCleanup Complete!")
    print(f"Total surviving MOSFETs: {pass_count}")
    print(f"Total rejected MOSFETs: {reject_count}")
    print(f"Saved to: {output_file}")

if __name__ == "__main__":
    main()