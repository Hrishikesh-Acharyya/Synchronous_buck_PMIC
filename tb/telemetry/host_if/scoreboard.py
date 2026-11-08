from spi_driver import spi_read
from host_if_constants import ADDR_TRIP_RUN, ADDR_SCRATCH, ADDR_BUS_ERR_L, ADDR_STATUS, ADDR_CONTROL, ADDR_STATUS, TELEMETRY_BYTES

async def read_thresholds(dut):
  """
  Purpose: 
  """

  threshold_bank = await spi_read(dut, ADDR_TRIP_RUN, 11)
  
  read_back = {
  "trip_run":         threshold_bank[0],
  "trip_ss":          threshold_bank[1],
  "max_strikes":      threshold_bank[2],
  "max_on_limit":     threshold_bank[3], 
  "hiccup_base":      threshold_bank[4] | (threshold_bank[5] << 8) | (threshold_bank[6] << 16),
  "cycles_per_step":  threshold_bank[7],
  "clean_run_target": threshold_bank[8] | (threshold_bank[9] << 8) | (threshold_bank[10] << 16) 
   }

  return read_back

async def scoreboard_check(dut, model):
  """
  Purpose: It reads back every register the model tracks, compares with the dut,
           and reports everry mismatch 
  """

  mismatches = []
  telemetry_read     = await spi_read(dut, ADDR_STATUS, TELEMETRY_BYTES)
  telemetry_expected = model.predict_reads(ADDR_STATUS, TELEMETRY_BYTES)
  for offset, (dut_byte, model_byte) in enumerate(zip(telemetry_read, telemetry_expected)):
    if dut_byte != model_byte:
      mismatches.append(f"telemetry {ADDR_STATUS + offset:#04x}: DUT {dut_byte:#04x}, model {model_byte:#04x}")


  dut_status_byte = await spi_read(dut, ADDR_STATUS, 1)
  dut_write_rejected = (dut_status_byte[0] >> 7) & 1 
  if(model.write_rejected != dut_write_rejected):
    mismatches.append(f"WRITE REJECTED: DUT{dut_write_rejected:#04x}, model {model.write_rejected:#04x}")

  dut_status_enable = (dut_status_byte[0] >> 5) & 1
  if model.spi_enable != dut_status_enable:
    mismatches.append(f"STATUS spi_enable: DUT {dut_status_enable}, model {model.spi_enable}")

  control_read = await spi_read(dut, ADDR_CONTROL, 1)
  dut_control  = control_read[0]
  model_control = (model.wd_restored << 3) | model.spi_enable
  if dut_control != model_control:
    mismatches.append(f"CONTROL: DUT {dut_control:#04x}, model {model_control:#04x}")


  thresholds = await read_thresholds(dut)

  for key,value in model.thresholds.items():
    if(value != thresholds[key]):
      mismatches.append(f"{key}: DUT {thresholds[key]:#04x}, model {value:#04x}")


  assert not mismatches, "scoreboard mismatch:\n" + "\n".join(mismatches)
  
  