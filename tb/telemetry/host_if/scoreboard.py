from spi_driver import spi_read
from host_if_constants import ADDR_TRIP_RUN, ADDR_SCRATCH, ADDR_BUS_ERR_L, ADDR_STATUS

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
  scratch_read = await spi_read(dut, ADDR_SCRATCH,1)
  if (model.scratch != scratch_read[0]):
    mismatches.append(f"SCRATCH: DUT {scratch_read[0]:#04x}, model {model.scratch:#04x}")

  bus_err_read = await spi_read(dut, ADDR_BUS_ERR_L, 2)
  dut_bus_err  = bus_err_read[0] | (bus_err_read[1] << 8)
  if(model.bus_err_count != dut_bus_err):
    mismatches.append(f"BUS ERROR COUNT: DUT {dut_bus_err:#04x}, model {model.bus_err_count:#04x}")


  dut_status_byte = await spi_read(dut, ADDR_STATUS, 1)
  dut_write_rejected = (dut_status_byte[0] >> 7) & 1 
  if(model.write_rejected != dut_write_rejected):
    mismatches.append(f"WRITE REJECTED: DUT{dut_write_rejected:#04x}, model {model.write_rejected:#04x}")


  thresholds = await read_thresholds(dut)

  for key,value in model.thresholds.items():
    if(value != thresholds[key]):
      mismatches.append(f"{key}: DUT {thresholds[key]:#04x}, model {value:#04x}")


  assert not mismatches, "scoreboard mismatch:\n" + "\n".join(mismatches)
  
  