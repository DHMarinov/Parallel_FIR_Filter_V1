--| |-----------------------------------------------------------|  |
--| |-----------------------------------------------------------|  |
--| |       _______           __      __      __          __    |  |
--| |     /|   __  \        /|  |   /|  |   /|  \        /  |   |  |
--| |    / |  |  \  \      / |  |  / |  |  / |   \      /   |   |  |
--| |   |  |  |\  \  \    |  |  | |  |  | |  |    \    /    |   |  |
--| |   |  |  | \  \  \   |  |  | |  |  | |  |     \  /     |   |  |
--| |   |  |  |  \  \  \  |  |  |_|__|  | |  |      \/      |   |  |
--| |   |  |  |   \  \  \ |  |          | |  |  |\      /|  |   |  |
--| |   |  |  |   /  /  / |  |   ____   | |  |  | \    / |  |   |  |
--| |   |  |  |  /  /  /  |  |  |__/ |  | |  |  |\ \  /| |  |   |  |
--| |   |  |  | /  /  /   |  |  | |  |  | |  |  | \ \//| |  |   |  |
--| |   |  |  |/  /  /    |  |  | |  |  | |  |  |  \|/ | |  |   |  |
--| |   |  |  |__/  /     |  |  | |  |  | |  |  |      | |  |   |  |
--| |   |  |_______/      |  |__| |  |__| |  |__|      | |__|   |  |
--| |   |_/_______/	      |_/__/  |_/__/  |_/__/       |_/__/   |  |
--| |                                                           |  |
--| |-----------------------------------------------------------|  |
--| |=============-Developed by Dimitar H.Marinov-==============/  /
--|_|----------------------------------------------------------/__/

--IP: Parallel FIR Filter
--Version: V1 - Standalone 
--Fuctionality: Generic FIR filter
--IO Description
--  clk     : system clock = sampling clock
--  reset   : resets the M registes (buffers) and the P registers (delay line) of the DSP48 blocks 
--  enable  : acts as bypass switch - bypass(0), active(1) 
--  data_i  : data input (signed)
--  data_o  : data output (signed)
--
--Generics Description
--  FILTER_TAPS  : Specifies the amount of filter taps (multiplications)
--  INPUT_WIDTH  : Specifies the input width (12-25 bits)
--  COEFF_WIDTH  : Specifies the coefficient width (12-18 bits)
--  OUTPUT_WIDTH : Specifies the output width (12-48 bits)
--
--Finished on: 30.06.2019
--Notes:
--------------------------------------------------------------------
--================= https://github.com/DHMarinov =================--
--------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Parallel_FIR_Filter is
    Generic (
        FILTER_TAPS  : integer := 60;
        INPUT_WIDTH  : integer range 8 to 24 := 24; 
        COEFF_WIDTH  : integer range 8 to 16 := 16;
        OUTPUT_WIDTH : integer range 8 to 48 := 24    -- This should be < (Input+Coeff width-1) 
    );
    Port ( 
           clk    : in STD_LOGIC;
           reset  : in STD_LOGIC;
           enable : in STD_LOGIC;
           data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           data_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0)
           );
end Parallel_FIR_Filter;

architecture Behavioral of Parallel_FIR_Filter is

attribute use_dsp : string;
attribute use_dsp of Behavioral : architecture is "yes";

constant MAC_WIDTH : integer := 43; -- COEFF_WIDTH+INPUT_WIDTH;
constant AREG_WIDTH : integer := 25;--
constant BREG_WIDTH : integer := 18;--

type input_registers is array(0 to FILTER_TAPS-1) of signed(AREG_WIDTH-1 downto 0);
signal areg_s  : input_registers := (others=>(others=>'0'));

type coeff_registers is array(0 to FILTER_TAPS-1) of signed(BREG_WIDTH-1 downto 0);
signal breg_s : coeff_registers := (others=>(others=>'0'));

type mult_registers is array(0 to FILTER_TAPS-1) of signed(AREG_WIDTH+BREG_WIDTH-1 downto 0);
signal mreg_s : mult_registers := (others=>(others=>'0'));

type dsp_registers is array(0 to FILTER_TAPS-1) of signed(MAC_WIDTH-1 downto 0);
signal preg_s : dsp_registers := (others=>(others=>'0'));

signal dout_s : std_logic_vector(MAC_WIDTH-1 downto 0);
signal sign_s : signed(MAC_WIDTH-INPUT_WIDTH-COEFF_WIDTH+1 downto 0) := (others=>'0');

type coefficients is array (0 to FILTER_TAPS-1) of signed(COEFF_WIDTH-1 downto 0);
signal coeff_s: coefficients :=( 

-- 500 Blackman LPF
x"0000", x"0001", x"0005", x"000C", 
x"0016", x"0025", x"0037", x"004E", 
x"0069", x"008B", x"00B2", x"00E0", 
x"0114", x"014E", x"018E", x"01D3", 
x"021D", x"026A", x"02BA", x"030B", 
x"035B", x"03AA", x"03F5", x"043B", 
x"047B", x"04B2", x"04E0", x"0504", 
x"051C", x"0528", x"0528", x"051C", 
x"0504", x"04E0", x"04B2", x"047B", 
x"043B", x"03F5", x"03AA", x"035B", 
x"030B", x"02BA", x"026A", x"021D", 
x"01D3", x"018E", x"014E", x"0114", 
x"00E0", x"00B2", x"008B", x"0069", 
x"004E", x"0037", x"0025", x"0016", 
x"000C", x"0005", x"0001", x"0000");

-- 1kHz Blackman LPF
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
--x"FFFF", x"FFFF", x"FFFF", x"0000");

-- 1kHz Blackman - causes overflow !!! 
--x"0000", x"FFFF", x"FFFF", x"FFFE", 
--x"FFFD", x"FFFC", x"FFFC", x"FFFE", 
--x"0003", x"000D", x"001E", x"0036", 
--x"0057", x"0084", x"00BE", x"0105", 
--x"015B", x"01BE", x"022E", x"02AA", 
--x"032F", x"03B9", x"0445", x"04CD", 
--x"054E", x"05C2", x"0626", x"0674", 
--x"06AA", x"06C6", x"06C6", x"06AA", 
--x"0674", x"0626", x"05C2", x"054E", 
--x"04CD", x"0445", x"03B9", x"032F", 
--x"02AA", x"022E", x"01BE", x"015B", 
--x"0105", x"00BE", x"0084", x"0057", 
--x"0036", x"001E", x"000D", x"0003", 
--x"FFFE", x"FFFC", x"FFFC", x"FFFD", 
--x"FFFE", x"FFFF", x"FFFF", x"0000");

-- Non repeating coefficients
--x"1010", x"1020", x"1030", x"1040", 
--x"2010", x"2020", x"2030", x"2040", 
--x"3010", x"3020", x"3030", x"3040", 
--x"4010", x"4020", x"4030", x"4040", 
--x"5010", x"5020", x"5030", x"5040", 
--x"6010", x"6020", x"6030", x"6040", 
--x"7010", x"7020", x"7030", x"7040", 
--x"8010", x"8020", x"8030", x"8040", 
--x"9010", x"9020", x"9030", x"9040", 
--x"a010", x"a020", x"a030", x"a040", 
--x"b010", x"b020", x"b030", x"b040", 
--x"c010", x"c020", x"c030", x"c040", 
--x"d010", x"d020", x"d030", x"d040", 
--x"e010", x"e020", x"e030", x"e040", 
--x"f010", x"f020", x"f030", x"f040"
--);

--type coefficients is array (0 to 59) of signed( 15 downto 0);
--signal coeff: coefficients :=( 
--x"0000", x"FFFF", x"FFFF", x"FFFE", x"FFFD", x"FFFC", 
--x"FFFC", x"FFFE", x"0003", x"000D", x"001E", x"0036", 
--x"0057", x"0084", x"00BE", x"0105", x"015B", x"01BE", 
--x"022E", x"02AA", x"032F", x"03B9", x"0445", x"04CD", 
--x"054E", x"05C2", x"0626", x"0674", x"06AA", x"06C6", 
--x"06C6", x"06AA", x"0674", x"0626", x"05C2", x"054E", 
--x"04CD", x"0445", x"03B9", x"032F", x"02AA", x"022E", 
--x"01BE", x"015B", x"0105", x"00BE", x"0084", x"0057", 
--x"0036", x"001E", x"000D", x"0003", x"FFFE", x"FFFC", 
--x"FFFC", x"FFFD", x"FFFE", x"FFFF", x"FFFF", x"0000");


begin

-- Coefficient formatting
Coeff_Array: for i in 0 to FILTER_TAPS-1 generate
    Coeff: for n in 0 to BREG_WIDTH-1 generate
        Coeff_Sign: if n > COEFF_WIDTH-2 generate
            breg_s(i)(n) <= coeff_s(i)(COEFF_WIDTH-1);
        end generate;
        Coeff_Value: if n < COEFF_WIDTH-1 generate
            breg_s(i)(n) <= coeff_s(i)(n);
        end generate;
    end generate;
end generate;

data_o <= std_logic_vector(preg_s(0)(INPUT_WIDTH+COEFF_WIDTH-2 downto INPUT_WIDTH+COEFF_WIDTH-OUTPUT_WIDTH-1));         


process(clk)

begin

if rising_edge(clk) then
    
    if (reset = '1') then
        for i in 0 to FILTER_TAPS-1 loop
            areg_s(i) <=(others=> '0');
            mreg_s(i) <=(others=> '0');
            preg_s(i) <=(others=> '0');
        end loop;
        
    elsif (reset = '0') then        
        for i in 0 to FILTER_TAPS-1 loop
            for n in 0 to AREG_WIDTH-1 loop
                if n > INPUT_WIDTH-2 then
                    areg_s(i)(n) <= data_i(INPUT_WIDTH-1);  -- Buffering
                else
                    areg_s(i)(n) <= data_i(n);              -- Buffering
                end if;
            end loop;
      
            if (i < FILTER_TAPS-1) then
                mreg_s(i) <= areg_s(i)*breg_s(i);         
                preg_s(i) <= mreg_s(i) + preg_s(i+1);
                        
            elsif (i = FILTER_TAPS-1) then
                mreg_s(i) <= areg_s(i)*breg_s(i); 
                preg_s(i)<= mreg_s(i);
            end if;
        end loop; 
        
        ------------------------------------------------------------
        --Over/Underflow Protection - Output multiplexing
        ------------------------------------------------------------
--        if preg_s(0)(47 downto INPUT_WIDTH+COEFF_WIDTH-2) = sign_s or preg_s(0)(47 downto INPUT_WIDTH+COEFF_WIDTH-2) = not(sign_s) then
--            data_o <= std_logic_vector(preg_s(0)(INPUT_WIDTH+COEFF_WIDTH-2 downto INPUT_WIDTH+COEFF_WIDTH-OUTPUT_WIDTH-1));         
--        else
--            if preg_s(0)(47) = '0' then
--                data_o(OUTPUT_WIDTH-1) <= '0';
--                data_o(OUTPUT_WIDTH-2 downto 0) <= (others=>'1');
--            else
--                data_o(OUTPUT_WIDTH-1) <= '1';
--                data_o(OUTPUT_WIDTH-2 downto 0) <= (others=>'0');
--            end if;
--        end if;
        
    end if;
end if;

end process;

end Behavioral;