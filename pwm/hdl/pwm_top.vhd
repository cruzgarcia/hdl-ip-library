LIBRARY IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.numeric_std.ALL;
  USE IEEE.std_logic_unsigned.ALL;
  USE IEEE.math_real.ALL;

ENTITY pwm_top IS
  GENERIC(
    G_ASYC_RESET              : BOOLEAN   := TRUE;
    G_RESET_VALUE             : STD_LOGIC := '1';
    G_PWM_MAX_PERIOD          : INTEGER   := 512;
    G_PWM_PERIOD_RESET_VALUE  : INTEGER   := 1;
    G_PWM_INACTIVE_VALUE      : STD_LOGIC := '1'
  );
  PORT(
    -- Clock
    i_clock           : IN  STD_LOGIC;
    i_reset           : IN  STD_LOGIC;
    -- PWM
    i_period          : IN  STD_LOGIC_VECTOR(INTEGER(CEIL(LOG2(REAL(G_PWM_MAX_PERIOD)))) DOWNTO 0);
    i_duty_cycle      : IN  STD_LOGIC_VECTOR(INTEGER(CEIL(LOG2(REAL(G_PWM_MAX_PERIOD)))) DOWNTO 0);
    i_enable          : IN  STD_LOGIC;
    o_pwm             : OUT STD_LOGIC
  );
END pwm_top;

ARCHITECTURE rtl OF pwm_top IS

  SIGNAL r_period_counter   : STD_LOGIC_VECTOR(INTEGER(CEIL(LOG2(REAL(G_PWM_MAX_PERIOD))))  DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_pwd              : STD_LOGIC;

BEGIN

  -- 
  proc_counter : PROCESS(i_reset, i_clock)
  BEGIN
    IF(i_reset = G_RESET_VALUE AND G_ASYC_RESET = TRUE)THEN
      -- Async reset
      r_period_counter        <= STD_LOGIC_VECTOR(TO_UNSIGNED(G_PWM_PERIOD_RESET_VALUE, r_period_counter'length));
    ELSIF RISING_EDGE(i_clock)THEN
      IF(i_reset = G_RESET_VALUE AND G_ASYC_RESET = FALSE)THEN
        -- Sync reset
        r_period_counter      <= STD_LOGIC_VECTOR(TO_UNSIGNED(G_PWM_PERIOD_RESET_VALUE, r_period_counter'length));
      ELSE
        IF(i_enable = '0' OR r_period_counter = i_period)THEN
          r_period_counter    <= STD_LOGIC_VECTOR(TO_UNSIGNED(G_PWM_PERIOD_RESET_VALUE, r_period_counter'length));
        ELSE
          r_period_counter    <= r_period_counter + '1';
        END IF;
      END IF;
    END IF;
  END PROCESS;

  proc_comp_comb : PROCESS(r_period_counter, i_duty_cycle, i_reset)
  BEGIN
    IF(i_reset = G_RESET_VALUE AND G_ASYC_RESET = TRUE)THEN
      s_pwd       <= G_PWM_INACTIVE_VALUE;
    ELSE
      IF(r_period_counter <= i_duty_cycle)THEN
        s_pwd     <= NOT G_PWM_INACTIVE_VALUE;
      ELSE
        s_pwd     <= G_PWM_INACTIVE_VALUE;
      END IF;
    END IF;
  END PROCESS;

  proc_out_reg : PROCESS(i_reset, i_clock)
  BEGIN
    IF(i_reset = G_RESET_VALUE AND G_ASYC_RESET = TRUE)THEN
      o_pwm <= G_PWM_INACTIVE_VALUE;
    ELSIF RISING_EDGE(i_clock) THEN
      IF(i_reset = G_RESET_VALUE AND G_ASYC_RESET = FALSE)THEN
        o_pwm <= G_PWM_INACTIVE_VALUE;
      ELSIF(i_enable = '1')THEN
        o_pwm <= s_pwd;
      ELSE
        o_pwm <= G_PWM_INACTIVE_VALUE;
      END IF;
    END IF;
  END PROCESS;

END rtl;