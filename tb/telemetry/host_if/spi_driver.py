from cocotb.triggers import Timer, FallingEdge
from host_if_constants import (SCK_HALF_PERIOD_NS, CLK_PERIOD_NS, READ_FLAG,
                               WRITE_MASK, CRC8_POLY)


def crc8(message_bytes):

    """
    Purpose: CRC-8/SMBUS (polynomial 0x07, init 0x00, MSB first, no
             reflection, no final XOR), list in, CRC out. Written from the
             published definition, not from spi_slave's RTL.
    """
    crc = 0
    for byte in message_bytes:
        crc = crc ^ byte
        for _ in range(8):
            if (crc >> 7) & 1:
                crc = ((crc << 1) & 0xFF) ^ CRC8_POLY
            else:
                crc = (crc << 1) & 0xFF
    return crc


def build_write_frame(address, data_bytes, corrupt_crc=False):

    """
    Purpose: The bytes of one write frame - [command][data ...][CRC-8] - with
             bit 7 of the command clear. corrupt_crc flips CRC bit 0, a
             single-bit error. Used by spi_write and by tests that send a
             frame through spi_transfer to cut or stall it.
    """
    frame = [address & WRITE_MASK] + data_bytes
    crc   = crc8(frame)
    if corrupt_crc:
        crc = crc ^ 0x01
    return frame + [crc]


async def spi_transfer(dut, tx_bytes, half_period_ns=SCK_HALF_PERIOD_NS,
                       stop_after_bits=None, pause_after_bits=None, pause_ns=0):

    """
    Purpose: One SPI transaction as the host MCU - CS_n low, the bits of
             tx_bytes shifted out on MOSI in Mode 0, MSB first, CS_n high.
             Returns the WHOLE bytes sampled on MISO; a partial last byte is
             dropped.

             The master owns SCK: every edge is made here. Per bit, MOSI is
             set while SCK is low, SCK rises a half-period later (the slave
             samples MOSI, the master samples MISO), and falls a half-period
             after that (the slave launches its next MISO bit). CS_n changes
             only while SCK is low and has been low for a half-period:
             spi_slave_sva checks this as a_cs_moves_with_sck_low. After CS_n
             rises it stays high for a half-period, longer than the 8-clock
             filter, so back-to-back transactions never merge.

             Misbehaving-host options (defaults reproduce a well-behaved one):
               half_period_ns   - SCK speed for this transaction; a multiple of
                                  CLK_PERIOD_NS so every edge stays on a falling
                                  clk edge (DRIVE_OFFSET).
               stop_after_bits  - raise CS_n after this many bits: a frame cut
                                  mid-byte or short. 0 = CS_n falls and rises
                                  with no clocks at all.
               pause_after_bits - before sending bit number pause_after_bits,
               pause_ns           hold SCK low with CS_n low for pause_ns; past
                                  spi_slave's SCK timeout this sends it to
                                  S_DEAD. Equal to the bit count = stall after
                                  the last bit.
    """
    assert half_period_ns % CLK_PERIOD_NS == 0, \
        f"half_period_ns={half_period_ns} must be a multiple of {CLK_PERIOD_NS}"
    assert pause_ns % CLK_PERIOD_NS == 0, \
        f"pause_ns={pause_ns} must be a multiple of {CLK_PERIOD_NS}"

    # every bit to send, MSB first, as one flat list - so a frame can be cut
    # or stalled at ANY bit, not only at byte boundaries
    bits = [(byte >> bit_index) & 1 for byte in tx_bytes for bit_index in range(7, -1, -1)]
    if stop_after_bits is not None:
        bits = bits[:stop_after_bits]

    # align to a falling clk edge: every later step is a multiple of the clk
    # period, so SCK, MOSI and CS_n never change on a rising edge (DRIVE_OFFSET)
    await FallingEdge(dut.clk)
    dut.CS_n.value = 0

    received_bits = []
    for bit_number, send_bit in enumerate(bits):
        if bit_number == pause_after_bits:
            await Timer(pause_ns, units="ns")       # SCK held low: the slave sees silence

        # SCK low: put this bit on MOSI before the rising edge
        dut.MOSI.value = send_bit
        await Timer(half_period_ns, units="ns")

        # rising edge: slave samples MOSI, master samples MISO
        dut.SCK.value = 1
        received_bits.append(int(dut.MISO.value))
        await Timer(half_period_ns, units="ns")

        # falling edge: slave launches its next MISO bit
        dut.SCK.value = 0

    # a stall asked for after the LAST bit sent
    if pause_after_bits is not None and pause_after_bits == len(bits):
        await Timer(pause_ns, units="ns")

    # lag time: SCK must be settled low before CS_n rises
    await Timer(half_period_ns, units="ns")
    dut.CS_n.value = 1
    # minimum CS-high time: must exceed the 8-clock filter window, or a
    # back-to-back transaction's CS_n rise is filtered out and the two merge
    await Timer(half_period_ns, units="ns")

    # group the sampled bits back into whole bytes, MSB first
    MISO_received_bytes = []
    for byte_start in range(0, len(received_bits) - len(received_bits) % 8, 8):
        received_byte = 0
        for bit in received_bits[byte_start:byte_start + 8]:
            received_byte = (received_byte << 1) | bit
        MISO_received_bytes.append(received_byte)

    return MISO_received_bytes


async def spi_write(dut, address, data_bytes, corrupt_crc=False,
                    half_period_ns=SCK_HALF_PERIOD_NS):

    """
    Purpose: One complete, well-formed write: build_write_frame, then
             spi_transfer. The write commits only if spi_slave's CRC agrees.
    """
    await spi_transfer(dut, build_write_frame(address, data_bytes, corrupt_crc),
                       half_period_ns=half_period_ns)


async def spi_read(dut, address, count, half_period_ns=SCK_HALF_PERIOD_NS):

    """
    Purpose: Burst read of count bytes from address: frame [command][turnaround]
             [count dummies]. Returns only the data bytes - the MISO bytes for
             the command and turnaround are dropped.
    """
    read_frame = [READ_FLAG | address, 0x00] + [0x00] * count
    result = await spi_transfer(dut, read_frame, half_period_ns=half_period_ns)
    return result[2:]