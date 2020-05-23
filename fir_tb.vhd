library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

entity fir_tb is
      Generic (
        WAITING_VALUE   : integer := 5;
        FIR_PROP_DLY    : integer := 3;
        COEFF_CHECK     : boolean := false;
       -- WAVE_STEPS      : integer := 32;
        CYCLES_PER_FREQ : integer range 1 to 1024 := 2;     -- Cycles spent on each frequency value.
        LOWEST_FREQ     : integer := 90;                  -- Fs/2048
      
      
        FILTER_TAPS  : integer := 60;
--      DSP_PER_CLMN : integer := 20;  
        INPUT_WIDTH  : integer := 24; 
        COEFF_WIDTH  : integer := 16;
        OUTPUT_WIDTH : integer := 24    -- This should be < (Input+Coeff width-1) 
    
   );
end;

architecture bench of fir_tb is

  component Parallel_FIR_Filter
      Generic (
         FILTER_TAPS  : integer := 60;
    --   DSP_PER_CLMN : integer := 20;  
         INPUT_WIDTH  : integer := 24; 
         COEFF_WIDTH  : integer := 16;
         OUTPUT_WIDTH : integer := 24    -- This should be < (Input+Coeff width-1) 
         );
    Port ( 
         clk    : in STD_LOGIC;
         reset  : in STD_LOGIC;
         enable : in STD_LOGIC;
         data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
         data_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0)
         );
  end component; 

signal clk    : STD_LOGIC := '0';   
signal reset  : STD_LOGIC := '0';
signal enable : STD_LOGIC := '1';
signal data_i : STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0) := (others => '0');
signal data_o : STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0) := (others => '0');

constant cp : time := 10ns;         
signal stop_sim : boolean := false;

-- Test banch state machine
type sim_state is (
    init,
    impls,
    step,    
    idle,
    wave,
    stop
);
signal state : sim_state := init;

signal counter : integer range 0 to FILTER_TAPS := 0;               -- Filter tap counter
signal maxima : integer range 0 to 10*FILTER_TAPS := WAITING_VALUE;    -- State machine parameter
signal coeff_s : std_logic_vector(COEFF_WIDTH-1 downto 0) := (others =>'0');
--signal wave_counter : integer range 0 to WAVE_STEPS-1 := WAVE_STEPS/2;
signal wave_direction : std_logic := '0';
signal wave_s : signed(INPUT_WIDTH-1 downto 0) := (others=>'0');
signal sweep_counter : integer range 0 to 2**INPUT_WIDTH-1 := 0;
signal sweep_increment : integer range 0 to 2**INPUT_WIDTH-1 := 0;
signal cycle_counter : integer range 0 to Cycles_per_freq-1 := 0;

signal test : std_logic := '0';
signal step_done : std_logic := '0';
signal check : boolean := false;
signal check_counter : integer range 0 to FILTER_TAPS := 0;               -- Filter tap counter
signal reference : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others=>'0'); 
signal exp : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others=>'0');

-- Filter coefficients
--type coefficients is array (0 to 59) of signed( 15 downto 0);
--signal coeff: coefficients :=( 
--x"0000", x"FFFF", x"FFFF", x"FFFF", 
--x"FFFF", x"FFFF", x"0001", x"0006", 
--x"000F", x"001D", x"0031", x"004D", 
--x"0072", x"00A2", x"00DE", x"0126", 
--x"017B", x"01DC", x"0249", x"02BE", 
--x"033B", x"03BC", x"043D", x"04BA", 
--x"0530", x"0599", x"05F3", x"063A", 
--x"066B", x"0684", x"0684", x"066B", 
--x"063A", x"05F3", x"0599", x"0530", 
--x"04BA", x"043D", x"03BC", x"033B", 
--x"02BE", x"0249", x"01DC", x"017B", 
--x"0126", x"00DE", x"00A2", x"0072", 
--x"004D", x"0031", x"001D", x"000F", 
--x"0006", x"0001", x"FFFF", x"FFFF", 
--x"FFFF", x"FFFF", x"FFF8", x"0000");

type coefficients is array (0 to 59) of signed( 15 downto 0);
signal coeff: coefficients :=( 
x"0000", x"FFFF", x"0000", x"0002", 
x"0005", x"000B", x"0012", x"0016", 
x"0015", x"000A", x"FFF2", x"FFCB", 
x"FF99", x"FF64", x"FF3A", x"FF2D", 
x"FF51", x"FFB4", x"005D", x"0145", 
x"0251", x"0356", x"0415", x"0445", 
x"0392", x"019B", x"FDDB", x"F735", 
x"E9A7", x"B02C", x"4FD4", x"1659", 
x"08CB", x"0225", x"FE65", x"FC6E", 
x"FBBB", x"FBEB", x"FCAA", x"FDAF", 
x"FEBB", x"FFA3", x"004C", x"00AF", 
x"00D3", x"00C6", x"009C", x"0067", 
x"0035", x"000E", x"FFF6", x"FFEB", 
x"FFEA", x"FFEE", x"FFF5", x"FFFB", 
x"FFFE", x"FFFF", x"0000", x"0000");

begin

------------------------------------------------------------
-- UUT
------------------------------------------------------------
  uut: Parallel_FIR_Filter
  generic map (
      INPUT_WIDTH => INPUT_WIDTH,  
      FILTER_TAPS => FILTER_TAPS, 
      COEFF_WIDTH => COEFF_WIDTH 
  )
  port map ( 
      clk    => clk,
      reset  => reset,
      enable => enable,
      data_i => data_i,
      data_o => data_o
   );
   
   
------------------------------------------------------------
-- Clock process
------------------------------------------------------------  
clock: process
begin

if (stop_sim = false) then
    clk <= '0', '1' after cp/2;
end if;
wait for cp;

end process;
   
   
------------------------------------------------------------
-- UUT
------------------------------------------------------------
stimulus: process(clk)
begin

if rising_edge(clk) then
    if (counter < maxima) then
        counter <= counter + 1;
    elsif (counter = maxima) then
        counter <= 0;
    end if;
    
    case state is
    when init =>                    -- Setting up the inital values and resetting the IP
        maxima <= WAITING_VALUE;
        stop_sim <= false;
        reset <= '1';
        enable <= '0';
        if (counter = maxima) then
            reset <= '0';
            enable <= '1';
            data_i(INPUT_WIDTH-1) <= '0';
            data_i(INPUT_WIDTH-2) <= '1';
            data_i(INPUT_WIDTH-3 downto 0) <= (others=>'0');
            state <= impls;
        end if;
        
    when impls =>                   -- Applying impulse reponse to the filter
        maxima <= FILTER_TAPS;
        data_i <= (others=>'0');
            if (counter < maxima) then
                coeff_s <= std_logic_vector(coeff(counter)); 
            end if;
--                if (coeff_s /= data_o(23)&data_o(22 downto 8)) then                
--                    enable <= '0';
--                end if;
        if (counter = maxima) then
            state <= idle;
        end if;
        
    when idle =>
        if (counter = maxima) then
            if (step_done = '0') then
                data_i(INPUT_WIDTH-1) <= '0';
                data_i(INPUT_WIDTH-2 downto 0) <= (others=>'1');
                state <= step;
            else
                state <= wave;
            end if;
            assert (false) report "Impulse response test is completed!"  severity failure;
        end if;  
        
        if (step_done) = '1' then
            maxima <= FILTER_TAPS;
            data_i(INPUT_WIDTH-1 downto 0) <= (others=>'0');
        else
            maxima <= WAITING_VALUE + FIR_PROP_DLY;
        end if;
         
    when step =>                     -- Applying step reponse to the filter
        maxima <= 10*FILTER_TAPS;
        
        if (counter > maxima/2) then
            data_i(INPUT_WIDTH-1) <= '1';
            data_i(INPUT_WIDTH-2 downto 0) <= (others=>'0');       
        end if;
        
        if (counter = maxima) then
            -- add logic here
            assert (false) report "Step response test is completed!" severity failure;
            state <= idle;
            step_done <= '1';
        end if;
        
    when wave =>
--        if wave_counter < WAVE_STEPS-1 then
--            wave_counter <= wave_counter + 1;
--         elsif wave_counter = WAVE_STEPS-1 then
--            wave_counter <= 0;
--            wave_direction <= not wave_direction;
--         end if;
         
--         if wave_direction = '0' then
--            wave_s <= wave_s + to_signed((2**INPUT_WIDTH-1)/WAVE_STEPS, INPUT_WIDTH);
--         else
--            wave_s <= wave_s - to_signed((2**INPUT_WIDTH-1)/WAVE_STEPS, INPUT_WIDTH);
--         end if; 
         
         data_i <= std_logic_vector(wave_s);

--    if sweep_counter < 2**INPUT_WIDTH-1 then
--        wave_s <= wave_s + to_signed(sweep_increment, 16);
--        sweep_counter <= sweep_counter + sweep_increment;
--    else
--        sweep_counter <= sweep_counter - 2**INPUT_WIDTH-1;
--        if cycle_counter < cycles_per_freq-1 then
--            cycle_counter <= cycle_counter + 1;
--        else
--            cycle_counter <= 0;
--            if sweep_increment < 2**INPUT_WIDTH then 
--                sweep_increment <= sweep_increment + 1024;
--            else
--                state <= stop;  
--            end if;
--        end if;   
--    end if;
    
    if sweep_counter < lowest_freq - sweep_increment then
        sweep_counter <= sweep_counter + 1;
    else
        sweep_counter <= 0;
        if cycle_counter < cycles_per_freq -1 then
            cycle_counter <= cycle_counter + 1;
        else
            cycle_counter <= 0;
            if sweep_increment < lowest_freq-1 then
                sweep_increment <= sweep_increment + 1;
            else
                state <= stop;
            end if;
        end if;
    end if; 
    
    if sweep_counter < (lowest_freq - sweep_increment)/2 then
        wave_s(INPUT_WIDTH-1) <= '0'; 
        wave_s(INPUT_WIDTH-2 downto 0) <= (others=>'1'); 
    else
        wave_s(INPUT_WIDTH-1) <= '1'; 
        wave_s(INPUT_WIDTH-2 downto 0) <= (others=>'0');     
    end if;
    
        
    when stop =>
        stop_sim <= true;
        assert (false) report "Step response test is completed!" severity failure;
    end case;
end if;

end process;



------------------------------------------------------------
-- Impulse response checking
------------------------------------------------------------  
checker: process(clk)

variable expected_value : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others=>'0');
variable a : integer :=5; 

begin

if rising_edge(clk) then
    if state = impls then
        -- Compensate for the propagation nelay of the filter
        if counter = FIR_PROP_DLY-1 then
            check <= true;
        end if;
    end if;
    
    if check = true and COEFF_CHECK = true then
        if check_counter < FILTER_TAPS-1 then
            -- Rifgtshift and format
            for i in 0 to OUTPUT_WIDTH-1 loop
                if i = OUTPUT_WIDTH-1 then
                    expected_value(i) := coeff(check_counter)(COEFF_WIDTH-1);
                elsif i < OUTPUT_WIDTH-1 and i > OUTPUT_WIDTH-COEFF_WIDTH-2 then
                    expected_value(i) := coeff(check_counter)(i-(OUTPUT_WIDTH-COEFF_WIDTH-1));
                else
                    expected_value(i) := '0';  
                end if;
            end loop;
            
            exp <= expected_value;
            check_counter <= check_counter + 1;
            -- the the output of the FIR filter
            if data_o /= expected_value then
                assert (false) report "Coefficient mismatch! Received value(u):" & integer'image(to_integer(unsigned(data_o))) &
                                      " Expected value(u):" & integer'image(to_integer(unsigned(expected_value))) &
                                      " Coefficient number:" & integer'image(check_counter) severity failure;
            end if;
            
        elsif check_counter = FILTER_TAPS-1 then
            check <= false;
        end if;
    end if;
end if;

end process;


  
end;