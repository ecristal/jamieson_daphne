-- top_level.vhd
-- for DAPHNE GbE AFE Readout
-- Target: XC7A200T-3FBG676C
-- Uses single GTX Transceiver connected to SFP optical module
-- Line rate is 1.25Gbps with refclk 125MHz

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library unimacro;
use unimacro.vcomponents.all;

use work.daphne_package.all;

entity top_level is
generic(version: std_logic_vector(27 downto 0) := X"1234567"); -- git commit number is passed in from tcl
port(

    reset_n:    in  std_logic; -- active LOW reset from the microcontroller
    sysclk_p:   in  std_logic; -- system clock LVDS 100MHz from local oscillator
	sysclk_n:   in  std_logic; -- (note internal 62.5MHz clock is generated from this 100MHz clock)

    -- AFE LVDS i/o

    afe_p, afe_n: array_5x9_type; -- (7..0=data, 8=frame)
    afe_clk_p:  out std_logic; -- copy of 62.5MHz master clock sent to AFEs
    afe_clk_n:  out std_logic;

    -- Gigabit Ethernet i/o

    gtrefclk_p: in  std_logic; -- refclk LVDS 125MHz
	gtrefclk_n: in  std_logic; 
    sfp_rx_p:   in  std_logic; 
	sfp_rx_n:   in  std_logic; 
	sfp_los:    in  std_logic; -- high if SFP RX fiber is dark
	sfp_tx_dis: out std_logic; -- high to disable SFP transmitter
    sfp_tx_p:   out std_logic; 
	sfp_tx_n:   out std_logic;

    -- misc board i/o

    trig_ext:   in std_logic; -- from back panel SMA connector, trigger on rising edge
    led:        out std_logic_vector(5 downto 0) -- DAPHNE PCB LEDs are active LOW

  );
end top_level;

architecture top_level_arch of top_level is

	-- declare components

	-- this version of the IP core (16.2) was generated for Artix 7 
	-- Vivado 2020.2
	-- extra debug ports are NOT needed on DAPHNE version since
	--  we don't need to invert the TXD and RXD pairs going to the SFP module

	component gig_ethernet_pcs_pma_0
      port(
		gtrefclk_p           : in std_logic;                     -- Very high quality clock for GT transceiver
		gtrefclk_n           : in std_logic;                    
		gtrefclk_out         : out std_logic;                  
		gtrefclk_bufg_out    : out std_logic;                           
      
		txp                  : out std_logic;                    -- Differential +ve of serial transmission from PMA to PMD.
		txn                  : out std_logic;                    -- Differential -ve of serial transmission from PMA to PMD.
		rxp                  : in std_logic;                     -- Differential +ve for serial reception from PMD to PMA.
		rxn                  : in std_logic;                     -- Differential -ve for serial reception from PMD to PMA.

		mmcm_locked_out      : out std_logic;                     -- Locked signal from MMCM
		userclk_out          : out std_logic;                  
		userclk2_out         : out std_logic;                 
		rxuserclk_out          : out std_logic;               
		rxuserclk2_out         : out std_logic;               
		independent_clock_bufg : in std_logic;                
		pma_reset_out         : out std_logic;                     -- transceiver PMA reset signal
		resetdone             :out std_logic;

		gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
		gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
		gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
		gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
		gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
		gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
		gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.
	
		configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
		an_interrupt         : out std_logic;                    -- Interrupt to processor to signal that Auto-Negotiation has completed
		an_adv_config_vector : in std_logic_vector(15 downto 0); -- Alternate interface to program REG4 (AN ADV)
		an_restart_config    : in std_logic;                     -- Alternate signal to modify AN restart bit in REG0

		status_vector        : out std_logic_vector(15 downto 0); -- Core status.
		reset                : in std_logic;                      -- Asynchronous reset for entire core.
		signal_detect        : in std_logic;                      -- Input from PMD to indicate presence of optical input.
		gt0_pll0outclk_out     : out std_logic;
		gt0_pll0outrefclk_out  : out std_logic;
		gt0_pll1outclk_out     : out std_logic;
		gt0_pll1outrefclk_out  : out std_logic;
		gt0_pll0refclklost_out : out std_logic;
		gt0_pll0lock_out       : out std_logic
    );
	end component;

    component ethernet_interface -- Ryan's OEI core logic
    port(
        reset_in:       in  std_logic;
        tx_data:        in  std_logic_vector(63 downto 0);
        ready:          in  std_logic;
        b_data:         in  std_logic_vector(63 downto 0);
        b_data_we:      in  std_logic;
        b_force_packet: in  std_logic;
        reset_out:      out std_logic;
        rx_addr:        out std_logic_vector(31 downto 0);
        rx_data:        out std_logic_vector(63 downto 0);
        rx_wren:        out std_logic;
        tx_rden:        out std_logic;
        b_enable:       out std_logic;
        user_addr:          in  std_logic_vector( 7 downto 0);
        internal_block_sel: in  std_logic_vector(31 downto 0);
        internal_addr:      in  std_logic_vector(31 downto 0);
        internal_din:       in  std_logic_vector(63 downto 0);
        internal_we:        in  std_logic;
        internal_dout:      out std_logic_vector(63 downto 0);
        phy_rxd:    in  std_logic_vector(7 downto 0);
        phy_rx_dv:  in  std_logic;
        phy_rx_er:  in  std_logic;
        master_clk: in  std_logic;
        phy_txd:    out std_logic_vector(7 downto 0);
        phy_tx_en:  out std_logic;
        phy_tx_er:  out std_logic;
        tx_clk:     out std_logic
    );
    end component;

    component fe
    port(
        afe_p, afe_n:         in  array_5x9_type;
        afe_clk_p, afe_clk_n: out std_logic; -- copy of 62.5MHz master clock sent to AFEs

        sclk:  in std_logic; -- 200MHz system clock, constant
        reset: in std_logic;
  
        delay_clk: in std_logic;
        delay_din: in std_logic_vector(4 downto 0);
        delay_ld:  in std_logic_vector(4 downto 0);

        mclk:    in std_logic; -- master clock 62.5MHz
        fclk:    in std_logic; -- 7 x master clock = 437.5MHz
        bitslip: in array_5x9_type;  -- sync to MCLK
        q:       out array_5x9x16_type
      );
    end component;

    component spy
    port(
        clka:  in std_logic;  
        reset: in std_logic; -- reset sync to clka
        trig:  in std_logic; -- trigger pulse sync to clka
        dia:   in std_logic_vector(15 downto 0); -- data bus from AFE channel    
        clkb:  in  std_logic;
        addrb: in  std_logic_vector(11 downto 0);
        dob:   out std_logic_vector(15 downto 0)
      );
    end component;

    component hpf_pedestal_recovery_filter_v5
    port(
        clk: in std_logic;
        reset: in std_logic;
        n_1_reset: in std_logic;
        enable: in std_logic;
        output_selector: in std_logic_vector(1 downto 0);
        x: in std_logic_vector(719 downto 0);
        trigger_output: out std_logic_vector(39 downto 0);
        y: out std_logic_vector(719 downto 0)
    );
    end component;
	
	-- declare signals to connect everything up

    signal gtrefclk_bufg_out, oeiclk, ready: std_logic;
    signal gtrefclk_p_ibuf, gtrefclk_n_ibuf: std_logic;

    signal gmii_rxd, gmii_txd: std_logic_vector(7 downto 0);
    signal gmii_tx_en, gmii_tx_er: std_logic;
    signal gmii_rx_dv, gmii_rx_er: std_logic;
    signal status_vector: std_logic_vector(15 downto 0);

    signal tx_data, rx_data: std_logic_vector(63 downto 0);
    signal rx_addr, rx_addr_reg: std_logic_vector(31 downto 0);
    signal tx_rden, rx_wren: std_logic;

    signal test_reg: std_logic_vector(63 downto 0);
    signal testreg_we: std_logic;

    signal bram0_we: std_logic_vector(3 downto 0);
    signal bram0_do: std_logic_vector(35 downto 0);

    signal fifo_DO: std_logic_vector(63 downto 0);
    signal dummy_RDCOUNT, dummy_WRCOUNT: std_logic_vector(8 downto 0);
    signal fifo_RDEN, fifo_WREN: std_logic;

    signal count_reg: std_logic_vector(23 downto 0);
    signal edge_reg: std_logic;
    signal led_temp, led1_reg, led0_reg: std_logic_vector(5 downto 0);

    -- DAPHNE specific signals...

	signal reset_async, reset_mclk: std_logic;
    signal fe_reset: std_logic;

    signal trig_sync, trig_gbe, trig_int_dead_time, trig_int_dead_time_reg0, trig_int_dead_time_reg1, trig_int_dead_time_reg2, trig_int_dead_time_total: std_logic;
    signal trig_gbe0_reg, trig_gbe1_reg, trig_gbe2_reg, trig_gbe_total: std_logic;
    signal trig_internal_enable: std_logic := '1';
    
    -- trigger state machine
    TYPE Tstate IS (trig_state_0, trig_state_1);
    SIGNAL trig_state: Tstate;
    SIGNAL trig_next_state: Tstate; 
    signal trig_dead_time_counter: std_logic_vector(11 downto 0) := (others => '0');
    signal trigger_internal: std_logic := '0';
    --
    
    signal sysclk_ibuf, clkfbout, clkfbout_buf, clkout0, clkout1, clkout2, clkout3, locked: std_logic;
    signal sclk: std_logic;
    signal mclk: std_logic;
    signal fclk: std_logic;
    signal ufclk: std_logic;

    signal bitslip_tmp, bitslip3_oei_reg, bitslip2_oei_reg, bitslip1_oei_reg, bitslip0_oei_reg: array_5x9_type;  
    signal bitslip0_mclk_reg, bitslip1_mclk_reg, bitslip_mclk: array_5x9_type;  

    signal delay_ld: std_logic_vector(4 downto 0);

    signal afe_dout: array_5x9x16_type;
    signal afe_dout_filtered: array_5x9x16_type;
    signal spy_bufr: array_5x9x16_type;

    signal afe_dout_pad_bits: std_logic_vector(719 downto 0);
    signal afe_dout_pad_filtered_bits: std_logic_vector(719 downto 0);
    
    signal timestamp_reg, ts_spy_bufr: std_logic_vector(63 downto 0);
    
    signal trigger_wire: std_logic_vector(39 downto 0);
    
begin

	-- sysclk is 100MHz LVDS, receive it with IBUFDS and drive it out on a BUFG net. sysclk comes in on bank 33
	-- which has VCCO=1.5V. IOSTANDARD is LVDS and the termination resistor is external (DIFF_TERM=FALSE)
    -- use MMCM/PLL to generate the following internal clocks:
    --
    --      200MHz used to calibrate the IDELAYs in the front end.
    --      62.5MHz master clock
    --      437.5MHz (7 x the master clock) used for ISERDES in the front end (also produce an inverted copy of this.)

	sysclk_ibufds_inst : IBUFGDS port map(O => sysclk_ibuf, I => sysclk_p, IB => sysclk_n);

    mmcm_inst: MMCME2_ADV
    generic map(
        BANDWIDTH            => "OPTIMIZED",
        CLKOUT4_CASCADE      => FALSE,
        COMPENSATION         => "ZHOLD",
        STARTUP_WAIT         => FALSE,
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 8.750,
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => FALSE,
        CLKOUT0_DIVIDE_F     => 4.375,
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT0_USE_FINE_PS  => FALSE,
        CLKOUT1_DIVIDE       => 14,
        CLKOUT1_PHASE        => 0.000,
        CLKOUT1_DUTY_CYCLE   => 0.500,
        CLKOUT1_USE_FINE_PS  => FALSE,
        CLKOUT2_DIVIDE       => 2,
        CLKOUT2_PHASE        => 0.000,
        CLKOUT2_DUTY_CYCLE   => 0.500,
        CLKOUT2_USE_FINE_PS  => FALSE,
        CLKOUT3_DIVIDE       => 1,
        CLKOUT3_PHASE        => 0.000,
        CLKOUT3_DUTY_CYCLE   => 0.500,
        CLKOUT3_USE_FINE_PS  => FALSE,
        CLKIN1_PERIOD        => 10.000
    )
    port map(
        CLKFBOUT            => clkfbout,
        CLKFBOUTB           => open,
        CLKOUT0             => clkout0,  -- 200MHz
        CLKOUT0B            => open,
        CLKOUT1             => clkout1,  -- 62.5MHz
        CLKOUT1B            => open,
        CLKOUT2             => clkout2,  -- 437.5MHz
        CLKOUT2B            => open,     -- 437.5MHz inverted  (was clkout2b)
        CLKOUT3             => clkout3,  -- 875 MHz
        CLKOUT3B            => open,
        CLKOUT4             => open,
        CLKOUT5             => open,
        CLKOUT6             => open,
        CLKFBIN             => clkfbout_buf,
        CLKIN1              => sysclk_ibuf,
        CLKIN2              => '0',
        CLKINSEL            => '1',
        DADDR               => (others=>'0'),
        DCLK                => '0',
        DEN                 => '0',
        DI                  => (others=>'0'),
        DO                  => open,
        DRDY                => open,
        DWE                 => '0',
        PSCLK               => '0',
        PSEN                => '0',
        PSINCDEC            => '0',
        PSDONE              => open,
        LOCKED              => locked,
        CLKINSTOPPED        => open,
        CLKFBSTOPPED        => open,
        PWRDWN              => '0',
        RST                 => reset_async
    );

    clkfb_inst: BUFG port map( I => clkfbout, O => clkfbout_buf);

    clk0_inst:  BUFG port map( I => clkout0, O => sclk);   -- system clock 200MHz

    clk1_inst:  BUFG port map( I => clkout1, O => mclk);   -- master clock 62.5MHz

    clk2_inst:  BUFG port map( I => clkout2, O => fclk);   -- fast clock 437.5MHz
    
    clk3_inst:  BUFG port map( I => clkout3, O => ufclk);   -- ultra fast clock 875MHz
  
    -- square up some async inputs in the mclk domain
    -- also make a fake 64 bit timestamp counter

	reset_async <= not reset_n;

    misc_proc: process(mclk)
    begin
        if rising_edge(mclk) then
            reset_mclk <= reset_async;
            if (reset_mclk='1') then
                timestamp_reg <= (others=>'0');
            else
                timestamp_reg <= std_logic_vector(unsigned(timestamp_reg) + 1);
            end if;
        end if;
    end process misc_proc;

    -- the trigger pulse can come from the outside world (aysnc) or from a write to a special address (oeiclk domain). 
    -- square this up and edge detect this and move it into the MCLK domain

    trig_gbe <= '1' when (std_match(rx_addr,TRIGGER_ADDR) and rx_wren='1') else '0';
    trig_int_dead_time <= '1' when (std_match(rx_addr,TRIGGER_INT_DEAD_TIME_ADDR) and rx_wren='1') else '0';

    trig_oei_proc: process(oeiclk)
    begin
        if rising_edge(oeiclk) then
            trig_gbe0_reg <= trig_gbe;
            trig_gbe1_reg <= trig_gbe0_reg;
            trig_gbe2_reg <= trig_gbe1_reg;
        end if;
    end process trig_oei_proc;
    
    trig_oei_proc_dead_time: process(oeiclk)
    begin
        if rising_edge(oeiclk) then
            trig_int_dead_time_reg0 <= trig_int_dead_time;
            trig_int_dead_time_reg1 <= trig_int_dead_time_reg0;
            trig_int_dead_time_reg2 <= trig_int_dead_time_reg1;
        end if;
    end process trig_oei_proc_dead_time;
    
    trig_gbe_total <= trig_gbe0_reg or trig_gbe1_reg or trig_gbe2_reg;
    trig_int_dead_time_total <= trig_int_dead_time_reg0 or trig_int_dead_time_reg1 or trig_int_dead_time_reg2;
    
    -- -- process to acount for dead time during reading of spy registers
    spy_buffer_reading_dead_time: process(trig_int_dead_time_total)
    begin
        if rising_edge(trig_int_dead_time_total) then
            trig_internal_enable <= not trig_internal_enable; 
        end if;
    end process spy_buffer_reading_dead_time;
    
    trigger_state_machine_state: process(mclk)
    begin 
        if (fe_reset = '1') then
            trig_state <= trig_state_0;
        elsif rising_edge(mclk) then
            trig_state <= trig_next_state; 
        end if; 
    end process trigger_state_machine_state;
    
    trigger_state_machine: process(trig_state)
    begin 
        case trig_state is
            when trig_state_0 =>
                if(trigger_wire(16) = '1') then
                    trig_next_state <= trig_state_1;
                    trigger_internal <= '1';
                else
                    trig_next_state <= trig_state_0;
                end if;
            when trig_state_1 =>
                if(trig_dead_time_counter(11) = '1') then
                    trig_dead_time_counter <= (others => '0');
                    trig_next_state <= trig_state_0;
                else
                    trig_dead_time_counter <= std_logic_vector(unsigned(trig_dead_time_counter) + 1);
                    trig_next_state <= trig_state_1;
                    trigger_internal <= '0';
                end if;     
        end case;
    end process trigger_state_machine;
        
    trig_proc: process(mclk)
    begin
        if rising_edge(mclk) then
            trig_sync <= trig_gbe_total or (trig_internal_enable and (trigger_internal or trig_ext)); -- spy buffer dead time 
            --trig_sync <= trig_ext or trig_align or trig_gbe_total or trigger_wire(16); -- original trigger
            -- or trigger_wire(0) or trigger_wire(1) or trigger_wire(2) or trigger_wire(3)
            -- or trigger_wire(4) or trigger_wire(5) or trigger_wire(6) or trigger_wire(7) 
            -- or trigger_wire(8) or trigger_wire(9) or trigger_wire(10) or trigger_wire(11)
            -- or trigger_wire(12) or trigger_wire(13) or trigger_wire(14) or trigger_wire(15)
            -- or trigger_wire(16) or trigger_wire(17) or trigger_wire(18) or trigger_wire(19)
            -- or trigger_wire(20) or trigger_wire(21) or trigger_wire(22) or trigger_wire(23)
            -- or trigger_wire(24) or trigger_wire(25) or trigger_wire(26) or trigger_wire(27)
            -- or trigger_wire(28) or trigger_wire(29) or trigger_wire(30) or trigger_wire(31)
            -- or trigger_wire(32) or trigger_wire(33) or trigger_wire(34) or trigger_wire(35)
            -- or trigger_wire(36) or trigger_wire(37) or trigger_wire(38) or trigger_wire(39); 
        end if;
    end process trig_proc;

    -- write anything to address RESETFE_ADDR to generate a special reset pulse for the FE logic
    -- one must do this before using the FE

    fe_reset <= '1' when (std_match(rx_addr,RESETFE_ADDR) and rx_wren='1') else '0';

    -- address decode idelay load pulse
    -- this signal originates in oeiclk domain (125MHz) and uses this clock to store value in idelay
    -- note this value range 0-31 and is write only for now, readback is not implemented.

    delay_ld(0) <= '1' when (std_match(rx_addr,DELAY_AFE0_ADDR) and rx_wren='1') else '0';
    delay_ld(1) <= '1' when (std_match(rx_addr,DELAY_AFE1_ADDR) and rx_wren='1') else '0';
    delay_ld(2) <= '1' when (std_match(rx_addr,DELAY_AFE2_ADDR) and rx_wren='1') else '0';
    delay_ld(3) <= '1' when (std_match(rx_addr,DELAY_AFE3_ADDR) and rx_wren='1') else '0';
    delay_ld(4) <= '1' when (std_match(rx_addr,DELAY_AFE4_ADDR) and rx_wren='1') else '0';

    -- address decode bitslip
    -- this signal originates in the oeiclk domain (125MHz) but must be resync in the in MCLK domain (62.5MHz) *AND* 
    -- it must be asserted for only *ONE* MCLK cycle. the oeiclk domain is faster, so pulse stretch
    -- it for 3 cycles, then edge detect this signal in the MCLK domain and assert this for one MCLK cycle    

    bitslip_tmp(0)(0) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D0_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(1) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D1_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(2) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D2_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(3) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D3_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(4) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D4_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(5) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D5_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(6) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D6_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(7) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_D7_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(0)(8) <= '1' when (std_match(rx_addr,BITSLIP_AFE0_FR_ADDR) and rx_wren='1') else '0';

    bitslip_tmp(1)(0) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D0_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(1) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D1_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(2) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D2_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(3) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D3_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(4) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D4_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(5) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D5_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(6) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D6_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(7) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_D7_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(1)(8) <= '1' when (std_match(rx_addr,BITSLIP_AFE1_FR_ADDR) and rx_wren='1') else '0';

    bitslip_tmp(2)(0) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D0_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(1) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D1_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(2) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D2_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(3) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D3_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(4) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D4_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(5) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D5_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(6) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D6_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(7) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_D7_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(2)(8) <= '1' when (std_match(rx_addr,BITSLIP_AFE2_FR_ADDR) and rx_wren='1') else '0';

    bitslip_tmp(3)(0) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D0_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(1) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D1_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(2) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D2_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(3) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D3_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(4) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D4_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(5) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D5_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(6) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D6_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(7) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_D7_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(3)(8) <= '1' when (std_match(rx_addr,BITSLIP_AFE3_FR_ADDR) and rx_wren='1') else '0';

    bitslip_tmp(4)(0) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D0_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(1) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D1_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(2) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D2_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(3) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D3_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(4) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D4_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(5) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D5_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(6) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D6_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(7) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_D7_ADDR) and rx_wren='1') else '0';
    bitslip_tmp(4)(8) <= '1' when (std_match(rx_addr,BITSLIP_AFE4_FR_ADDR) and rx_wren='1') else '0';

    bs_oei_proc: process(oeiclk) -- 125MHz domain
    begin
        if rising_edge(oeiclk) then
            bitslip0_oei_reg <= bitslip_tmp;
            bitslip1_oei_reg <= bitslip0_oei_reg;
            bitslip2_oei_reg <= bitslip1_oei_reg;
            for a in 4 downto 0 loop
                for b in 8 downto 0 loop
                    bitslip3_oei_reg(a)(b) <= bitslip2_oei_reg(a)(b) or bitslip1_oei_reg(a)(b) or bitslip0_oei_reg(a)(b); -- will be high for minimum 3 oei clks
                end loop;
            end loop;
        end if;
    end process bs_oei_proc;

    bs_mclk_proc: process(mclk) -- 62.5MHz
    begin
        if rising_edge(mclk) then
            bitslip0_mclk_reg <= bitslip3_oei_reg; 
            bitslip1_mclk_reg <= bitslip0_mclk_reg;
        end if;
    end process bs_mclk_proc;

    gen_bs_afe: for a in 4 downto 0 generate
        gen_bs_bit: for b in 8 downto 0 generate
            bitslip_mclk(a)(b) <= '1' when ( bitslip1_mclk_reg(a)(b)='0' and bitslip0_mclk_reg(a)(b)='1' ) else '0';
            afe_dout_pad_bits(((a*9 + b)*16 + 15) downto ((a*9 + b)*16)) <= afe_dout(a)(b);
            afe_dout_filtered(a)(b) <= afe_dout_pad_filtered_bits(((a*9 + b)*16 + 15) downto ((a*9 + b)*16));
        end generate gen_bs_bit;
    end generate gen_bs_afe;

    -- now instantiate the AFE front end, total 45 channels (40 AFE data channels + 5 frame marker channels)

    fe_inst: fe 
    port map(

        afe_p => afe_p,
        afe_n => afe_n,
        afe_clk_p => afe_clk_p,
        afe_clk_n => afe_clk_n,

        mclk  => mclk,
        fclk  => fclk,
        sclk  => sclk,
        reset => fe_reset,

        delay_clk => oeiclk,
        delay_din => rx_data(4 downto 0),
        delay_ld  => delay_ld(4 downto 0),

        bitslip   => bitslip_mclk,
        q => afe_dout -- mclk domain 5x9x16
    );

    filter_inst: hpf_pedestal_recovery_filter_v5
    port map(
        clk => mclk,
        reset => fe_reset,
        n_1_reset => '0',
        enable => led_temp(1),
        output_selector => (others => '0'),
        x => afe_dout_pad_bits,
        trigger_output => trigger_wire,
        y => afe_dout_pad_filtered_bits
    );

    -- make 45 spy buffers for AFE data, these buffers are READ ONLY

    gen_spy_afe: for a in 4 downto 0 generate
        gen_spy_bit: for b in 8 downto 0 generate
            spy_inst: spy
            port map(
                -- mclk domain
                clka  => mclk,
                reset => reset_mclk,
                trig  => trig_sync,
                dia   => afe_dout_filtered(a)(b),
                -- oeiclk domain    
                clkb  => oeiclk,
                addrb => rx_addr_reg(11 downto 0),
                dob   => spy_bufr(a)(b));
        end generate gen_spy_bit;
    end generate gen_spy_afe;

    -- make 4 more spy buffers which are used to store the 64-bit timestamp value

    ts_spy_gen: for i in 3 downto 0 generate

        ts_spy_inst: spy
        port map(
            -- mclk domain
            clka  => mclk,
            reset => reset_mclk,
            trig  => trig_sync,
            dia   => timestamp_reg( ((i*16)+15) downto (i*16) ),

            -- oeiclk domain    
            clkb  => oeiclk,
            addrb => rx_addr_reg(11 downto 0),
            dob   => ts_spy_bufr( ((i*16)+15) downto (i*16) )
          );

    end generate ts_spy_gen;

    -- must manually add IBUFs for refclk inputs
    -- see http://forums.xilinx.com/t5/Implementation/Vivado-IBUFDS-GTE2-driven-by-IBUF/td-p/383187

    gtrefclk_p_ibuf_inst: IBUF port map ( I => gtrefclk_p, O => gtrefclk_p_ibuf );
    gtrefclk_n_ibuf_inst: IBUF port map ( I => gtrefclk_n, O => gtrefclk_n_ibuf );
 
	phy_inst: gig_ethernet_pcs_pma_0 
	port map(
		gtrefclk_p    => gtrefclk_p_ibuf,
        gtrefclk_n    => gtrefclk_n_ibuf,
        gtrefclk_out  => open,
        gtrefclk_bufg_out => gtrefclk_bufg_out, -- constant 125MHz derived from REFCLK
        txp               => sfp_tx_p,
        txn               => sfp_tx_n,
        rxp               => sfp_rx_p,
        rxn               => sfp_rx_n,
        mmcm_locked_out        => open,
        userclk_out            => open, 
        userclk2_out           => oeiclk, -- 125MHz clock to drive OEI logic, does it run constantly?
        rxuserclk_out          => open,
        rxuserclk2_out         => open, 
        independent_clock_bufg => sclk,   -- 200MHz system clock always running
        pma_reset_out          => open,
        resetdone              => open,
        gmii_txd     => gmii_txd,
        gmii_tx_en   => gmii_tx_en,
        gmii_tx_er   => gmii_tx_er,
        gmii_rxd     => gmii_rxd,
        gmii_rx_dv   => gmii_rx_dv,
        gmii_rx_er   => gmii_rx_er,
        gmii_isolate => open,
        configuration_vector(4 downto 0) => "10000",  -- Autoneg=1, Isolate=0, PowerDown=0, Loopback=0, Unidir=0 
        an_interrupt          => open,
        an_adv_config_vector  => X"0020",  -- AN FD, see PG047 table 2-55
        an_restart_config     => '0',
        status_vector         => status_vector, -- PG047 table 2-41
        reset                 => reset_async,
        signal_detect         => '1',   -- no optics, signal is always present
		gt0_pll0outclk_out => open,
		gt0_pll0outrefclk_out => open,
		gt0_pll1outclk_out => open,
		gt0_pll1outrefclk_out => open,
		gt0_pll0refclklost_out => open,
		gt0_pll0lock_out => open
      );

	-- make sure SFP transmitter is enabled!

	sfp_tx_dis <= '0';

	-- 'off the shelf' Ethernet Interface (OEI)
    -- burst mode not used here

    eth_int_inst: ethernet_interface
    port map(
        reset_in       => reset_async, 
        tx_data        => tx_data,
        ready          => ready,
        b_data         => X"0000000000000000",  -- burst mode not used
        b_data_we      => '0',
        b_force_packet => '0',
        reset_out      => open,
        rx_addr        => rx_addr,
        rx_data        => rx_data,
        rx_wren        => rx_wren,
        tx_rden        => tx_rden,
        b_enable       => open,
        user_addr          => OEI_USR_ADDR,
        internal_block_sel => X"00000000",  -- internal access not used
        internal_addr      => X"00000000",
        internal_din       => X"0000000000000000",
        internal_we        => '0',
        -- internal_dout   => 
        phy_rxd    => gmii_rxd,
        phy_rx_dv  => gmii_rx_dv,
        phy_rx_er  => gmii_rx_er,
        master_clk => oeiclk,
        phy_txd    => gmii_txd,
        phy_tx_en  => gmii_tx_en,
        phy_tx_er  => gmii_tx_er,
        tx_clk     => open
    );

    -- delay the read address by one clock, this register will be used to drive the readback mux
    -- going to Ethernet interface
    
    readmux_proc: process(oeiclk)
    begin
        if rising_edge(oeiclk) then
            rx_addr_reg <= rx_addr;
        end if;
    end process readmux_proc;

    -- BIG mux to determine what 64 bit value gets sent back to the Ethernet Interface

    tx_data <= test_reg                        when std_match(rx_addr_reg, TESTREG_ADDR) else 
               fifo_DO                         when std_match(rx_addr_reg, FIFO_ADDR) else 
               (X"00000000000" & "000" & locked & status_vector) when std_match(rx_addr_reg, STATVEC_ADDR) else  -- the status register
               (X"00000000deadbeef")           when std_match(rx_addr_reg, DEADBEEF_ADDR) else
               (X"0000000"&bram0_do)           when std_match(rx_addr_reg, BRAM0_ADDR) else
               (X"000000000"&version)          when std_match(rx_addr_reg, GITVER_ADDR) else  -- 28 bit GIT commit hash

               (X"000000000000" & spy_bufr(0)(0))  when std_match(rx_addr_reg, SPYBUF_AFE0_D0_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(1))  when std_match(rx_addr_reg, SPYBUF_AFE0_D1_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(2))  when std_match(rx_addr_reg, SPYBUF_AFE0_D2_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(3))  when std_match(rx_addr_reg, SPYBUF_AFE0_D3_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(4))  when std_match(rx_addr_reg, SPYBUF_AFE0_D4_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(5))  when std_match(rx_addr_reg, SPYBUF_AFE0_D5_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(6))  when std_match(rx_addr_reg, SPYBUF_AFE0_D6_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(7))  when std_match(rx_addr_reg, SPYBUF_AFE0_D7_BASEADDR) else
               (X"000000000000" & spy_bufr(0)(8))  when std_match(rx_addr_reg, SPYBUF_AFE0_FR_BASEADDR) else
         
               (X"000000000000" & spy_bufr(1)(0))  when std_match(rx_addr_reg, SPYBUF_AFE1_D0_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(1))  when std_match(rx_addr_reg, SPYBUF_AFE1_D1_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(2))  when std_match(rx_addr_reg, SPYBUF_AFE1_D2_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(3))  when std_match(rx_addr_reg, SPYBUF_AFE1_D3_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(4))  when std_match(rx_addr_reg, SPYBUF_AFE1_D4_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(5))  when std_match(rx_addr_reg, SPYBUF_AFE1_D5_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(6))  when std_match(rx_addr_reg, SPYBUF_AFE1_D6_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(7))  when std_match(rx_addr_reg, SPYBUF_AFE1_D7_BASEADDR) else
               (X"000000000000" & spy_bufr(1)(8))  when std_match(rx_addr_reg, SPYBUF_AFE1_FR_BASEADDR) else

               (X"000000000000" & spy_bufr(2)(0))  when std_match(rx_addr_reg, SPYBUF_AFE2_D0_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(1))  when std_match(rx_addr_reg, SPYBUF_AFE2_D1_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(2))  when std_match(rx_addr_reg, SPYBUF_AFE2_D2_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(3))  when std_match(rx_addr_reg, SPYBUF_AFE2_D3_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(4))  when std_match(rx_addr_reg, SPYBUF_AFE2_D4_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(5))  when std_match(rx_addr_reg, SPYBUF_AFE2_D5_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(6))  when std_match(rx_addr_reg, SPYBUF_AFE2_D6_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(7))  when std_match(rx_addr_reg, SPYBUF_AFE2_D7_BASEADDR) else
               (X"000000000000" & spy_bufr(2)(8))  when std_match(rx_addr_reg, SPYBUF_AFE2_FR_BASEADDR) else

               (X"000000000000" & spy_bufr(3)(0))  when std_match(rx_addr_reg, SPYBUF_AFE3_D0_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(1))  when std_match(rx_addr_reg, SPYBUF_AFE3_D1_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(2))  when std_match(rx_addr_reg, SPYBUF_AFE3_D2_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(3))  when std_match(rx_addr_reg, SPYBUF_AFE3_D3_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(4))  when std_match(rx_addr_reg, SPYBUF_AFE3_D4_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(5))  when std_match(rx_addr_reg, SPYBUF_AFE3_D5_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(6))  when std_match(rx_addr_reg, SPYBUF_AFE3_D6_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(7))  when std_match(rx_addr_reg, SPYBUF_AFE3_D7_BASEADDR) else
               (X"000000000000" & spy_bufr(3)(8))  when std_match(rx_addr_reg, SPYBUF_AFE3_FR_BASEADDR) else

               (X"000000000000" & spy_bufr(4)(0))  when std_match(rx_addr_reg, SPYBUF_AFE4_D0_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(1))  when std_match(rx_addr_reg, SPYBUF_AFE4_D1_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(2))  when std_match(rx_addr_reg, SPYBUF_AFE4_D2_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(3))  when std_match(rx_addr_reg, SPYBUF_AFE4_D3_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(4))  when std_match(rx_addr_reg, SPYBUF_AFE4_D4_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(5))  when std_match(rx_addr_reg, SPYBUF_AFE4_D5_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(6))  when std_match(rx_addr_reg, SPYBUF_AFE4_D6_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(7))  when std_match(rx_addr_reg, SPYBUF_AFE4_D7_BASEADDR) else
               (X"000000000000" & spy_bufr(4)(8))  when std_match(rx_addr_reg, SPYBUF_AFE4_FR_BASEADDR) else

               ts_spy_bufr(63 downto 0) when std_match(rx_addr_reg, SPYBUFTS_BASEADDR) else 

               (X"00000000" & rx_addr_reg);

    -- drive the READY signal back to OEI immediately, this means immediate writes and 
    -- read latency of 1. Specific to the OEI handshaking.

    ready <= rx_wren or tx_rden;

    -- 64-bit R/W dummy register for testing reads and writes
    -- located at address 0x12345678

    testreg_we <= '1' when (std_match(rx_addr,TESTREG_ADDR) and rx_wren='1') else '0';

    test_proc: process(oeiclk)
    begin
        if rising_edge(oeiclk) then
            if (reset_async='1') then
                test_reg <= (others=>'0');
            elsif (testreg_we='1') then
                test_reg <= rx_data;
            end if;
        end if;
    end process test_proc;

    -- test: connect a single port 1k x 36 blockRAM to the OTS
    -- this memory block maps into 0x00070000 - 0x000703FF
 
    bram0_we <= "1111" when (std_match(rx_addr,BRAM0_ADDR) and rx_wren='1') else "0000";

    BRAM0_inst : BRAM_SINGLE_MACRO -- 1k x 36, 10 bit addr
    generic map(
        BRAM_SIZE => "36Kb",
        DEVICE => "7SERIES",
        DO_REG => 0,  -- no output register, read latency of 1 clk
        INIT => X"000000000",
        INIT_FILE => "NONE",
        WRITE_WIDTH => 36,
        READ_WIDTH => 36,
        SRVAL => X"000000000",
        WRITE_MODE => "READ_FIRST"
    )   
    port map(
        DO    => bram0_do(35 downto 0),
        ADDR  => rx_addr(9 downto 0),
        CLK   => oeiclk,
        DI    => rx_data(35 downto 0),
        EN    => '1',
        REGCE => '1',
        RST   => '0',
        WE    => bram0_we
    );

    -- test FIFO is 512 x 64. what happens if we try to read from an empty FIFO?

    fifo_WREN <= '1' when (std_match(rx_addr,FIFO_ADDR) and rx_wren='1') else '0'; 
    fifo_RDEN <= '1' when (std_match(rx_addr,FIFO_ADDR) and tx_rden='1') else '0'; 
    
    FIFO_SYNC_inst: FIFO_SYNC_MACRO
    generic map (
        DEVICE => "7SERIES",
        ALMOST_FULL_OFFSET => X"0080",
        ALMOST_EMPTY_OFFSET => X"0080",
        DATA_WIDTH => 64,
        FIFO_SIZE => "36Kb")
    port map (
        ALMOSTEMPTY => open,
        ALMOSTFULL => open,
        DO => fifo_DO,
        EMPTY => open,
        FULL => open,
        RDCOUNT => dummy_RDCOUNT,
        RDERR => open,
        WRCOUNT => dummy_WRCOUNT,
        WRERR => open,
        CLK => oeiclk,
        DI => rx_data,
        RDEN => fifo_RDEN,
        RST => reset_async,
        WREN => fifo_WREN
    );

	-- DAPHNE has 6 LEDs controlled by the FPGA, which are labeled on the PCB like this:
    --  led(5)   led(4)     led(3)     led(2)    led(1)    led(0)
    -- "LED14"   "LED13"    "LED4"     "LED3"    "LED2"    "LED1"    "LED5 (uC)"     

	led_temp(0) <= locked;           -- "LED1" on if main PLL MMCM locked and clocks running
    led_temp(1) <= not sfp_los;      -- "LED2" on if SFP module is detecting a signal
	led_temp(2) <= status_vector(0); -- "LED3" on if Ethernet link is UP
	led_temp(3) <= '1' when (status_vector(11 downto 10)="10") else '0'; -- "LED4" on if link speed is 1000
	led_temp(4) <= gmii_rx_dv or gmii_tx_en; -- "LED13" is on if there is ethernet RX or TX activity
	led_temp(5) <= trig_sync;        -- "LED14" is on when DAPHNE is triggered 

	-- LED driver logic. pulse stretch fast signals so they are visible (aka a "one shot")
	-- Use a fast clock to sample the signal led_temp. whenever led_temp is HIGH, led0_reg
	-- goes high and stays high. periodically (200MHz / 2^24 = 11Hz) copy led0_reg into led1_reg 
	-- and reset led0_reg. this insures that the output signal led1_reg is HIGH for a whole
	-- 11Hz cycle, regardless of when the blip on the led_temp occurs.

    oneshot_proc: process(sclk)
    begin
        if rising_edge(sclk) then
            if (reset_async='1') then
                count_reg <= (others=>'0');
                edge_reg  <= '0';
                led0_reg <= (others=>'0');
				led1_reg <= (others=>'0');
            else
                count_reg <= std_logic_vector(unsigned(count_reg) + 1);
                edge_reg  <= count_reg(23);

                if (edge_reg='0' and count_reg(23)='1') then -- MSB of the counter was JUST set
                    led1_reg <= led0_reg;
                    led0_reg <= (others=>'0');
                else
                    led0_reg <= led0_reg or led_temp;
                end if;
            end if;
        end if;
    end process oneshot_proc;
   
    -- DAPHNE LEDs are ACTIVE LOW

    led <= not led1_reg;

end top_level_arch;
