library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;

entity serial_tx is
  Generic(
    g_data_width        : integer := 8;
    g_clock_freq        : integer := 125_000_000;
    g_baudrate          : integer := 115_200
  );
  Port(
    -- Clock and reset
    i_clock           : in  std_logic;
    i_reset           : in  std_logic;
    -- Input data
    i_data            : in  std_logic_vector(g_data_width-1 downto 0);
    i_data_valid      : in  std_logic;
    -- UART TX
    o_txd             : out std_logic
  );
end;

architecture rtl of serial_tx is

  -- Baudrate calculation
  constant tx_div   : integer := (g_clock_freq / g_baudrate) - 1;

  -- TXD States
  type state_type is (TX_IDLE, TX_GET_WORD,
     TX_START_0, TX_WAIT_SEND_0, TX_STOP_0,
     TX_START_1, TX_WAIT_SEND_1, TX_STOP_1);

  -- Signals
  signal tx_current_state, tx_next_state : state_type;
  signal tx_tick               : std_logic;   
  signal tx_data               : std_logic_vector (7 downto 0);
  signal tx_in_mux_data        : std_logic;
  signal tx_mux_ctrl           : std_logic_vector (3 downto 0);
  signal tx_mux_data           : std_logic;
  signal tx_tick_mod           : std_logic_vector(14 downto 0);
  signal tx_tick_rst           : std_logic;  
  signal tx_busy               : std_logic;
  signal tx_cnt                : std_logic_vector(3 downto 0);
  signal tx_cnt_done           : std_logic;
  signal tx_cnt_rst            : std_logic;
  signal tx_cnt_en             : std_logic;   
  signal nibble_sel            : std_logic;
  signal take_input_data       : std_logic;
  signal rst_n                 : std_logic;

begin   

  -- Sync process for RX/TX FSM
  sync_proc : process(i_clock)
  begin
    if rising_edge(i_clock) then 
      if(i_reset='1') then
        tx_current_state <= TX_IDLE;
      else
        tx_current_state <= tx_next_state;
      end if;
    end if;
  end process sync_proc;   
  
  -- TX States sequences
  tx_sequence : process(all)
  begin
    case tx_current_state is
      
      when TX_IDLE =>
        tx_busy         <= '0';
        tx_mux_ctrl     <= x"0";
        tx_tick_rst     <= '1';
        tx_cnt_rst      <= '1';
        tx_cnt_en       <= '0';
        take_input_data <= '0';
        
        if(i_data_valid = '1') then
          tx_next_state <= TX_GET_WORD;
        else
          tx_next_state <= TX_IDLE;
        end if;

      when TX_GET_WORD =>
        tx_busy         <= '1';
        tx_mux_ctrl     <= x"2";
        tx_tick_rst     <= '0';
        tx_cnt_rst      <= '0';
        tx_cnt_en       <= '0';
        take_input_data <= '1';
        
        tx_next_state   <= TX_START_0;
        
      when TX_START_0 =>
        tx_busy         <= '1';
        tx_mux_ctrl     <= x"2";
        tx_tick_rst     <= '0';
        tx_cnt_rst      <= '0';
        tx_cnt_en       <= '1';
        take_input_data <= '0';
        
        if(tx_tick = '1') then
          tx_next_state <= TX_WAIT_SEND_0;
        else
          tx_next_state <= TX_START_0;
        end if;

      when TX_WAIT_SEND_0 =>
        tx_busy         <= '1';
        tx_mux_ctrl     <= x"1";
        tx_tick_rst     <= '0';
        tx_cnt_rst      <= '0';
        tx_cnt_en       <= '1';
        take_input_data <= '0';
        
        if(tx_cnt_done = '1' and tx_tick = '1') then
          tx_next_state <= TX_STOP_0;
        else
          tx_next_state <= TX_WAIT_SEND_0;
        end if;                      
        
      when TX_STOP_0  =>
        tx_busy         <= '1';
        tx_mux_ctrl     <= x"0";
        tx_tick_rst     <= '0';
        tx_cnt_rst      <= '1';
        tx_cnt_en       <= '0';
        take_input_data <= '0';
        
        if(tx_tick = '1') then
          tx_next_state <= TX_IDLE;
        else
          tx_next_state <= TX_STOP_0;
        end if; 
        
      when others =>
        tx_busy         <= '0';
        tx_mux_ctrl     <= x"0";
        tx_tick_rst     <= '0';
        tx_cnt_rst      <= '0';
        tx_cnt_en       <= '0';
        take_input_data <= '0';
        
        tx_next_state <= TX_IDLE;
        
    end case;
  end process tx_sequence;

  --TX tick  
  tx_tick_gen : process(i_clock)
  begin
    if rising_edge(i_clock) then      
      if(i_reset = '1' or tx_tick_rst = '1') then
        tx_tick         <= '0';
        tx_tick_mod     <= (others => '0');
      else        
        tx_tick_mod     <= tx_tick_mod + '1';        
        if(tx_tick_mod = tx_div) then
          tx_tick_mod   <= (others => '0');
          tx_tick       <= '1';
        else
          tx_tick <= '0';
        end if;                        
      end if;      
    end if;
  end process tx_tick_gen;
  
  -- tx bit counter
  bitcnt : process(i_clock)
  begin
    if rising_edge(i_clock) then
      if(i_reset = '1' or tx_cnt_rst = '1') then
        tx_cnt <= (others => '0');
      elsif(tx_cnt_en = '1' and tx_tick = '1') then
        tx_cnt <= tx_cnt + 1;
      end if;
    end if;
  end process bitcnt;

  -- tx bit counter decoder
  decoder : process(tx_cnt)
  begin
    if(tx_cnt = x"8") then
      tx_cnt_done <= '1';
    else
      tx_cnt_done <= '0';
    end if;
  end process decoder;

  -- Input data registers
  in_data_reg : process(i_clock)
  begin
    if rising_edge(i_clock) then
      tx_data         <= i_data;
    end if;
  end process in_data_reg;
  
  --TX data "mux"
  tx_data_sel : process(tx_cnt, tx_data)
  begin    
    case tx_cnt is      
      when x"1" =>
        tx_in_mux_data <= tx_data(0);
      when x"2" =>
        tx_in_mux_data <= tx_data(1);
      when x"3" =>
        tx_in_mux_data <= tx_data(2);
      when x"4" =>
        tx_in_mux_data <= tx_data(3);
      when x"5" =>
        tx_in_mux_data <= tx_data(4);
      when x"6" =>
        tx_in_mux_data <= tx_data(5);
      when x"7" =>
        tx_in_mux_data <= tx_data(6);
      when x"8" =>
        tx_in_mux_data <= tx_data(7);
      when others =>
        tx_in_mux_data <= '0';        
    end case;
  end process tx_data_sel;

-- TX Data multiplexor
  tx_mux : process(tx_mux_ctrl,tx_in_mux_data)
  begin
    case tx_mux_ctrl is
      when x"0" =>
        tx_mux_data <= '1';
      when x"1" =>
        tx_mux_data <= tx_in_mux_data;
      when x"2" =>
        tx_mux_data <= '0';
      when others =>
        tx_mux_data <= '1';
    end case;
  end process tx_mux;

  txd_proc : process(i_clock)
  begin
    if rising_edge(i_clock) then
      o_txd <= tx_mux_data;
    end if;
  end process txd_proc;
  
end rtl;


