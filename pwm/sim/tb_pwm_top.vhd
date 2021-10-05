
LIBRARY ieee;
  USE ieee.std_logic_1164.ALL;
  USE ieee.numeric_std.ALL;
  use IEEE.std_logic_unsigned.all;
  use ieee.math_real.all;

  LIBRARY vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.sync_pkg.all;

LIBRARY OSVVM;
  CONTEXT OSVVM.OSVVMContext;

ENTITY tb_pwm_top IS
  GENERIC(
    G_ASYC_RESET              : BOOLEAN               := TRUE;
    G_RESET_VALUE             : STD_LOGIC             := '1';
    G_PWM_MAX_PERIOD          : INTEGER               := 512;
    G_PWM_PERIOD_RESET_VALUE  : INTEGER               := 1;
    G_PWM_INACTIVE_VALUE      : STD_LOGIC             := '0';
    -- VUnit
    runner_cfg                : STRING
  );
END tb_pwm_top;

ARCHITECTURE rtl OF tb_pwm_top IS

  CONSTANT c_clock_period   : TIME := 5 ns;

  SIGNAL s_clock        : STD_LOGIC := '0';
  SIGNAL s_reset        : STD_LOGIC := '1';
  SIGNAL s_pwm          : STD_LOGIC := '0';
  SIGNAL s_pwm_r1       : STD_LOGIC := '0';
  -- PWM
  SIGNAL s_enable       : STD_LOGIC := '0';
  SIGNAL s_period       : STD_LOGIC_VECTOR(INTEGER(ceil(log2(real(G_PWM_MAX_PERIOD)))) DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_duty_cycle   : STD_LOGIC_VECTOR(INTEGER(ceil(log2(real(G_PWM_MAX_PERIOD)))) DOWNTO 0) := (OTHERS => '0');
  -- 
  SIGNAL r_dc_count_int   : INTEGER := 0;

BEGIN
    
  show(display_handler, pass);

  CreateClock ( 
    s_clock,
    c_clock_period
  );

  CreateReset (
    s_reset,
    G_RESET_VALUE,
    s_clock,
    10*c_clock_period,
    0ns
  );

  test_runner_setup(runner, runner_cfg);
  test_runner : process
  BEGIN
    -- Initial values
    s_enable          <= '0';
    s_period          <= (OTHERS => '0');
    s_duty_cycle      <= (OTHERS => '0');

    WHILE test_suite loop
      IF run("duty_cycle_50") THEN
        -- Set a duty cycle of 50% of the period
        s_period      <= STD_LOGIC_VECTOR(TO_UNSIGNED(128, s_period'LENGTH));
        s_duty_cycle  <= STD_LOGIC_VECTOR(TO_UNSIGNED( 64, s_duty_cycle'LENGTH));
        s_enable      <= '1';
        WaitForClock(s_clock, 500);
      END IF;
    END LOOP;
    WAIT FOR 1000 us;
  END PROCESS;

  test_check : PROCESS
  BEGIN
    
    IF running_test_case = "duty_cycle_50" THEN
      WaitForClock(s_clock, 500);
      WaitForLevel(s_enable, '1');
      WaitForLevel(s_pwm, '0');
      WaitForClock(s_clock, 100);
    END IF;
    WaitForClock(s_clock, 100);
  END PROCESS;

  proc_counter : PROCESS(s_reset, s_clock)
  BEGIN
    IF(s_reset = '1')THEN
      r_dc_count_int  <= 0;
    ELSIF RISING_EDGE(s_clock)THEN
      IF(s_pwm = '1')THEN
      r_dc_count_int <= r_dc_count_int + 1;
      END IF;
    END IF;
  END PROCESS;
  --=================================================================
  --= DUT ===========================================================
  --=================================================================
  inst_dut : ENTITY WORK.pwm_top
  GENERIC MAP(
    G_ASYC_RESET              => G_ASYC_RESET,
    G_RESET_VALUE             => G_RESET_VALUE,
    G_PWM_MAX_PERIOD          => G_PWM_MAX_PERIOD,
    G_PWM_PERIOD_RESET_VALUE  => G_PWM_PERIOD_RESET_VALUE,
    G_PWM_INACTIVE_VALUE      => G_PWM_INACTIVE_VALUE
  )PORT MAP(
    -- Clock
    i_clock               => s_clock,
    i_reset               => s_reset,
    -- PWM
    i_period              => s_period,
    i_duty_cycle          => s_duty_cycle,
    i_enable              => s_enable,
    o_pwm                 => s_pwm
  );
  --=================================================================
END rtl ;