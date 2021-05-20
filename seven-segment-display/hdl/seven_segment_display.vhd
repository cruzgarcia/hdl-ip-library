 library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;

entity seven_segment_display is
  generic(
    g_digit_width       : integer := 4;
    g_displ_active_high : boolean := true;
    g_displ_data_width  : integer := 7
  );
  port(
    -- Clock
    i_clock     : in  std_logic;
    i_reset     : in  std_logic;
    -- 
    i_digit     : in  std_logic_vector(g_digit_width-1 downto 0);
    i_digit_va  : in  std_logic;
    -- 8 Segment
    o_segment_disp  : out std_logic_vector(g_displ_data_width-1 downto 0)
  );
end seven_segment_display;

architecture rtl of seven_segment_display is

  signal r_segment_disp : std_logic_vector(g_displ_data_width-1 downto 0);

begin

    proc_decoder : PROCESS(i_reset, i_clock)
    begin
      if rising_edge(i_clock)then
        if(i_reset = '1')then
          r_segment_disp          <= (others => '0');
        else
          if(i_digit_va = '1')then
            case i_digit is
              -- a b c d e f g
              when x"0" => 
                r_segment_disp    <= b"1111110";
              when x"1" => 
                r_segment_disp    <= b"0110000";
              when x"2" => 
                r_segment_disp    <= b"1101101";
              when x"3" => 
                r_segment_disp    <= b"1111001";
              when x"4" => 
                r_segment_disp    <= b"0110011";
              when x"5" => 
                r_segment_disp    <= b"1011011";
              when x"6" => 
                r_segment_disp    <= b"0011111";
              when x"7" => 
                r_segment_disp    <= b"1110000";
              when x"8" => 
                r_segment_disp    <= b"1111111";
              when x"9" => 
                r_segment_disp    <= b"1110011";
              when x"A" => 
                r_segment_disp    <= b"1110111";
              when x"B" => 
                r_segment_disp    <= b"0011111";
              when x"C" => 
                r_segment_disp    <= b"1001110";
              when x"D" => 
                r_segment_disp    <= b"0111101";
              when x"E" => 
                r_segment_disp    <= b"1001111";
              when x"F" => 
                r_segment_disp    <= b"1000111";
              when others => 
                r_segment_disp    <= (others => '0');
            end case;
          end if;
        end if;
      end if;
    end process;

  gen_active_high : if g_displ_active_high = true generate
    o_segment_disp <= r_segment_disp;
  end generate gen_active_high;

  gen_active_low : if g_displ_active_high = false generate
    o_segment_disp <= not r_segment_disp;
  end generate gen_active_low;

END rtl;