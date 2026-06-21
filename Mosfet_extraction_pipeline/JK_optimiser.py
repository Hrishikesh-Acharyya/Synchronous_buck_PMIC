import pandas as pd
import numpy as np
import re

# --- CONFIGURATION ---
input_file = 'cleaned_mosfets.xlsx'
output_file = 'frequency_optimization_matrix.xlsx'

col_status = 'Validation_Status'
col_part   = 'Part_Number'
col_mfg    = 'Manufacturer'
col_rds    = 'Rds_on_max_mOhm'
col_qsw    = 'Qsw_switching_nC'
col_qg     = 'Qg_total_nC' 
col_ratio  = 'Qg_Qsw_ratio' 

# System Parameters
V_IN = 21.0
V_OUT = 5.0
I_OUT = 5.0
I_PP = 1.5       
V_DRIVE = 10.0   
I_DRIVE = 1.2    

def extract_number(val):
    if pd.isna(val): return 0.0
    match = re.search(r'[\d\.]+', str(val))
    return float(match.group()) if match else 0.0

def main():
    print("Loading valid silicon data...")
    try:
        df = pd.read_excel(input_file)
    except FileNotFoundError:
        print(f"Error: Could not find {input_file}")
        return

    df_valid = df[df[col_status] == 'PASS'].copy()
    
    # Extract clean numbers
    df_valid['Rds_num'] = df_valid[col_rds].apply(extract_number)
    df_valid['Qsw_num'] = df_valid[col_qsw].apply(extract_number)
    df_valid['Qg_num']  = df_valid[col_qg].apply(extract_number)
    df_valid['Ratio_num'] = df_valid[col_ratio].apply(extract_number)
    
    # BULLETPROOF FILTER
    # If the ratio is missing, we drop the part to avoid false optimizations
    df_valid = df_valid[
        (df_valid['Rds_num'] > 0) & 
        (df_valid['Qsw_num'] > 0) & 
        (df_valid['Qg_num'] > 0) &
        (df_valid['Ratio_num'] > 0) 
    ]
    
    K_HS = 1e-3 * (I_OUT**2 + (1/12) * I_PP**2) * (V_OUT / V_IN)

    # 100k to 800k in 25k steps
    frequencies = range(100000, 825000, 25000)
    
    master_records = []

    print("Generating 25 kHz Sweep Matrix...\n")

    for freq in frequencies:
        freq_results = []
        
        for index, row in df_valid.iterrows():
            part_name = f"{row[col_mfg]} {row[col_part]}"
            rds = row['Rds_num']
            qsw = row['Qsw_num']
            qg  = row['Qg_num']
            ratio = row['Ratio_num']
            
            # The Full J Equation utilizing your pre-extracted ratio
            J_HS = 1e-9 * ((V_IN * I_OUT / I_DRIVE) + (ratio * V_DRIVE)) * freq
            
            total_loss = (K_HS * rds) + (J_HS * qsw)
            
            # Driver loss: P = Qg * V_drive * Freq
            driver_loss_hs = (qg * 1e-9) * V_DRIVE * freq
            
            freq_results.append({
                'Frequency_kHz': freq / 1000,
                'Part_Number': part_name,
                'Total_Loss_W': total_loss,
                'Rds_on_mOhm': rds,
                'Qsw_nC': qsw,
                'Qg_nC': qg,
                'Ratio': ratio,
                'HS_Driver_Heat_W': driver_loss_hs
            })
            
        # Sort by lowest loss for this specific frequency slice
        freq_results.sort(key=lambda x: x['Total_Loss_W'])
        
        # Grab top 5 and assign rankings
        for rank, result in enumerate(freq_results[:5], start=1):
            result['Rank'] = rank
            master_records.append(result)

    # Convert to DataFrame and export
    matrix_df = pd.DataFrame(master_records)
    
    # Reorder columns for readability
    cols = ['Frequency_kHz', 'Rank', 'Part_Number', 'Total_Loss_W', 'HS_Driver_Heat_W', 'Rds_on_mOhm', 'Qsw_nC', 'Qg_nC', 'Ratio']
    matrix_df = matrix_df[cols]
    
    matrix_df.to_excel(output_file, index=False)
    print(f"Matrix Complete! Saved {len(master_records)} ranked data points to: {output_file}")
    
    # Quick Terminal Output for the 350kHz slice
    print("\n--- SNEAK PEEK: The 350 kHz Slice ---")
    slice_350 = matrix_df[matrix_df['Frequency_kHz'] == 350.0]
    for idx, row in slice_350.iterrows():
        print(f"#{row['Rank']}: {row['Part_Number']} | Loss: {row['Total_Loss_W']:.3f} W | Driver Heat: {row['HS_Driver_Heat_W']:.3f} W")

if __name__ == "__main__":
    main()