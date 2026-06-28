import pandas as pd
import numpy as np
import re

# --- CONFIGURATION ---
input_file = 'excel_sheets/cleaned_mosfets.xlsx'
output_file = 'excel_sheets/low_side_frequency_matrix_LM5106.xlsx'

col_status = 'Validation_Status'
col_part   = 'Part_Number'
col_mfg    = 'Manufacturer'
col_rds    = 'Rds_on_max_mOhm'
col_qsw    = 'Qsw_switching_nC'
col_qg     = 'Qg_total_nC' 
col_ratio  = 'Qg_Qsw_ratio' 
col_vsd    = 'Vsd_body_diode_Volts' 

# System Parameters for LM5106. Uncomment this and comment out the other set if you want to use LM5106 parameters.
V_IN = 22.0
V_OUT = 5.0
I_OUT = 5.0
I_PP = 1.5       
V_DRIVE = 10.0   
I_SOURCE = 1.2   # LM5106 Peak Source Current
I_SINK = 1.8     # LM5106 Peak Sink Current      

# # System Parameters for UCC27282. Uncomment this and comment out the other set if you want to use UCC27282 parameters.
# V_IN = 22.0
# V_OUT = 5.0
# I_OUT = 5.0
# I_PP = 1.5       
# V_DRIVE = 10.0   
# I_SOURCE = 2.5   # UCC27282 Peak Source Current
# I_SINK = 3.5     # UCC27282 Peak Sink Current

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
    df_valid['Vsd_num'] = df_valid[col_vsd].apply(extract_number)
    
    # FILTER
    df_valid = df_valid[
        (df_valid['Rds_num'] > 0) & 
        (df_valid['Qsw_num'] > 0) & 
        (df_valid['Qg_num'] > 0) &
        (df_valid['Ratio_num'] > 0) 
    ]
    
    # LOW-SIDE CONSTANT (1 - Duty Cycle)
    K_LS = 1e-3 * (I_OUT**2 + (1/12) * I_PP**2) * (1 - (V_OUT / V_IN))

    # 100k to 800k in 25k steps
    frequencies = range(100000, 825000, 25000)
    
    master_records = []

    print("Generating Low-Side 25 kHz Sweep Matrix...\n")

    for freq in frequencies:
        freq_results = []
        
        for index, row in df_valid.iterrows():
            part_name = f"{row[col_mfg]} {row[col_part]}"
            rds = row['Rds_num']
            qsw = row['Qsw_num']
            qg  = row['Qg_num']
            ratio = row['Ratio_num']
            
            # --- LOW-SIDE FET PHYSICS (LM5106 Fixed Dead-Time) ---
            
            # Use the real datasheet Vsd, fallback to 0.8V ONLY if missing
            v_fd = row['Vsd_num'] if row['Vsd_num'] > 0 else 0.8
            
            # 1. OHMIC CONDUCTION LOSS (The 'K' Term)
            conduction_loss = K_LS * rds
            
            # 2. DIODE DEAD-TIME LOSS (Replaces the 'J' Term)
            # The LM5106 Rdt pin forces exactly 50ns rising + 50ns falling dead time.
            # Loss = V * I * t * f
            #Worst case dead timing is 200ns total (100ns rising + 100ns falling) for the LM5106 with 10k resistor on Rdt pin. This is a conservative estimate to account for variations in the dead time due to temperature, process, and voltage.
            t_deadtime_total = 200e-9 
            diode_loss = v_fd * I_OUT * t_deadtime_total * freq
            
            # 3. TOTAL MOSFET HEAT (What the heatsink sees)
            total_loss = conduction_loss + diode_loss
            
            # 4. DRIVER IC HEAT (The battery drain caused by Qg)
            # P = Qg * V_drive * Freq
            driver_loss_ls = (qg * 1e-9) * V_DRIVE * freq
            
            freq_results.append({
                'Frequency_kHz': freq / 1000,
                'Part_Number': part_name,
                'Total_Loss_W': total_loss,
                'Rds_on_mOhm': rds,
                'Qsw_nC': qsw, # Kept for the dataframe structure, but not used in the loss math!
                'Qg_nC': qg,
                'V_fd_Volts': v_fd,
                'Ratio': ratio,
                'LS_Driver_Heat_W': driver_loss_ls
            })
            
        # Sort by lowest loss for this specific frequency slice
        freq_results.sort(key=lambda x: x['Total_Loss_W'])
        
        # Grab top 5 and assign rankings
        for rank, result in enumerate(freq_results[:5], start=1):
            result['Rank'] = rank
            master_records.append(result)

    # Convert to DataFrame and export
    matrix_df = pd.DataFrame(master_records)
    
    # Reorder columns
    cols = ['Frequency_kHz', 'Rank', 'Part_Number', 'Total_Loss_W', 'LS_Driver_Heat_W', 'Rds_on_mOhm', 'Qsw_nC', 'Qg_nC', 'V_fd_Volts', 'Ratio']
    matrix_df = matrix_df[cols]
    
    matrix_df.to_excel(output_file, index=False)
    print(f"Matrix Complete! Saved {len(master_records)} ranked data points to: {output_file}")
    
    # Quick Terminal Output for the 450kHz slice
    print("\n--- SNEAK PEEK: The 450 kHz Slice ---")
    slice_450 = matrix_df[matrix_df['Frequency_kHz'] == 450.0]
    for idx, row in slice_450.iterrows():
        print(f"#{row['Rank']}: {row['Part_Number']} | Loss: {row['Total_Loss_W']:.3f} W | Driver Heat: {row['LS_Driver_Heat_W']:.3f} W | Vfd: {row['V_fd_Volts']}V")

if __name__ == "__main__":
    main()