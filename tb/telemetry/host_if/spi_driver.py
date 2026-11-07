from cocotb.triggers import Timer, FallingEdge
from host_if_constants import SCK_HALF_PERIOD_NS, READ_FLAG, WRITE_MASK, CRC8_POLY


async def spi_transfer(dut, tx_bytes):

    """
    Purpose: One complete SPI transaction as the host MCU - CS_n low, every
             byte of tx_bytes shifted out on MOSI in Mode 0, MSB first, then
             CS_n high. Returns the bytes sampled on MISO, one per byte sent.
             The master owns SCK: every edge is made here. Per bit, MOSI is
             set while SCK is low, SCK rises a half-period later (the slave
             samples MOSI, the master samples MISO), and falls a half-period
             after that (the slave launches its next MISO bit).

             CS_n changes only while SCK is low and has been low for a
             half-period: the lead time is the first bit's setup wait, the lag
             time is the wait before CS_n rises. spi_slave_sva checks this as
             a_cs_moves_with_sck_low.
             
    """
    # align to a falling clk edge: every later step is a multiple of the clk
    # period, so SCK, MOSI and CS_n never change on a rising edge (DRIVE_OFFSET)
    await FallingEdge(dut.clk)
    MISO_received_bytes = []
    dut.CS_n.value = 0

    for byte in tx_bytes:
        received_byte = 0

        for bit_index in range(7, -1, -1):
            # SCK low: put this bit on MOSI before the rising edge
            send_bit = (byte >> bit_index) & 1
            dut.MOSI.value = send_bit
            await Timer(SCK_HALF_PERIOD_NS, units="ns")

            # rising edge: slave samples MOSI, master samples MISO
            dut.SCK.value = 1
            received_bit = int(dut.MISO.value)
            received_byte = (received_bit << bit_index) | received_byte
            await Timer(SCK_HALF_PERIOD_NS, units="ns")

            # falling edge: slave launches its next MISO bit
            dut.SCK.value = 0

        MISO_received_bytes.append(received_byte)

    # lag time: SCK must be settled low before CS_n rises
    await Timer(SCK_HALF_PERIOD_NS, units="ns")
    dut.CS_n.value = 1
    # stay with cs_high for atleast half a period, so that new transactions
    # don't pull cs_n low very soon and get the pulse classified as a glitch 
    # byt the filter 
    await Timer(SCK_HALF_PERIOD_NS, units="ns")
    

    return MISO_received_bytes

def crc8(message_bytes): 

    """
    Purpose: CRC-8/SMBUS (polynomial 0x07, init 0x00, MSB first,
             no reflection, no final XOR), list in, CRC out.
    """
    crc = 0
    for byte in message_bytes:

        crc = crc ^ byte

        for _ in range(8):
            if(((crc >> 7) & 1) == 1): 
                crc = (crc <<1) & 0xFF
                crc = crc^CRC8_POLY
            else: 
                crc = (crc <<1) & 0xFF

    return crc

async def spi_write(dut, address, data_bytes, corrupt_crc=False): 

    """
    Purpose: Write structure: [COMMAND][DATA][CRC], bit 7 of command 0 for write transaction
             The crc covers command and data. The write is only commited if spi_slave
             crc agrees
    """

    write_command = WRITE_MASK & address
    write_frame = [write_command] + data_bytes
    crc = crc8(write_frame)

    if corrupt_crc:
        crc = crc ^ 0x01      # single-bit error: what one EMI hit does

    write_frame = write_frame + [crc]
    await spi_transfer(dut, write_frame)


async def spi_read(dut, address, count):

    """
    Purpose: Read frame = [COMMAND][TURN_AROUND]([DUMMY]*No of bytes to be read)
    """

    read_command = READ_FLAG | address
    # turnaround byte us 0x00
    read_frame = [read_command, 0x00] + [0x00]*count
    result = await spi_transfer(dut,read_frame)
    # return everything except first 2 bytes, which are the slave's answer
    # to command and turnaround bytes
    return result[2:]
