-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
--
-- Author: Richard Harman
-- Login: xharma05
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

-- ----------------------------------------------------------------------------
--                        Signal declaration
-- ----------------------------------------------------------------------------

    signal PC_REG   : std_logic_vector (11 downto 0);
    signal PC_INC   : std_logic;
    signal PC_DEC   : std_logic;
    signal PC_RST   : std_logic;

    signal PTR_REG  : std_logic_vector (9 downto 0);
    signal PTR_INC  : std_logic;
    signal PTR_DEC  : std_logic;
    signal PTR_RST  : std_logic;

    signal CNT_REG  : std_logic_vector (11 downto 0);
    signal CNT_INC  : std_logic;
    signal CNT_DEC  : std_logic;
    signal CNT_RST  : std_logic;

    signal MX_WDATA : std_logic_vector (7 downto 0);
    signal MX_SEL   : std_logic_vector (1 downto 0) := "00";

-- ----------------------------------------------------------------------------
--                   FSM machine states declaration
-- ----------------------------------------------------------------------------

	type state is (
		start, 
		ins, 
		decode, 
		inc_state, inc_state_0, inc_state_1, inc_state_2, 
		dec_state, dec_state_0, dec_state_1, dec_state_2, 
		while_0, while_1, while_2, while_en, 
		end_cycle_0, end_cycle_1, end_cycle_2, end_cycle_3, end_cycle_en, 
		output_0, output_1, 
		input_0, input_1, 
		stop_cycle, stop_cycle_1, stop_cycle_en, 
		null_state, 
		other_state 
	);
  signal fsm_prev_state : state := start; 
  signal fsm_state : state;

begin

-- ----------------------------------------------------------------------------
--                          PROGRAM COUNTER 
-- ----------------------------------------------------------------------------

    pc_counter: process (CLK, RESET, PC_INC, PC_DEC)
    begin
      if RESET = '1' then
        PC_REG <= (others => '0');
      elsif CLK'event and CLK = '1' then
        if PC_INC = '1' then
          PC_REG <= PC_REG +1;
        elsif PC_DEC = '1' then
          PC_REG <= PC_REG -1;
        elsif PC_RST = '1' then
          PC_REG <= (others => '0');
        end if;  
      end if;
    end process;

-- ----------------------------------------------------------------------------
--                       MEMORY POINTER COUNTER 
-- ----------------------------------------------------------------------------

    ptr_counter: process (CLK, RESET, PTR_INC, PTR_DEC)
    begin
      if RESET = '1' then
        PTR_REG <= (others => '0');
      elsif CLK'event and CLK = '1' then
        if PTR_INC = '1' then
          PTR_REG <= PTR_REG +1;
        elsif PTR_DEC = '1' then
          PTR_REG <= PTR_REG -1;
        elsif PTR_RST = '1' then
          PTR_REG <= (others => '0');
        end if;  
      end if;
    end process;

-- ----------------------------------------------------------------------------
--                  WHILE CYCLE - PARENTHESIS COUNTER 
-- ----------------------------------------------------------------------------

    cnt_counter: process (CLK, RESET, CNT_INC, CNT_DEC)
    begin
      if RESET = '1' then
        CNT_REG <= (others => '0');
      elsif CLK'event and CLK = '1' then
        if CNT_INC = '1' then
          CNT_REG <= CNT_REG +1;
        elsif CNT_DEC = '1' then
          CNT_REG <= CNT_REG -1;
        elsif CNT_RST = '1' then
          CNT_REG <= (others => '0');
        end if;  
      end if;
    end process;

-- ----------------------------------------------------------------------------
--                     MULTIPLEXOR DATA SELECTOR 
-- ----------------------------------------------------------------------------

    wdata_processor: process (CLK, RESET, MX_SEL)
    begin
      if RESET = '1' then
        MX_WDATA <= (others => '0');
      elsif CLK'event and CLK = '1' then
        case MX_SEL is
          when "00" =>
            MX_WDATA <= IN_DATA;
          when "01" =>
            MX_WDATA <= DATA_RDATA +1;
          when "10" =>
            MX_WDATA <= DATA_RDATA -1;
          when others =>
            MX_WDATA <= (others => '0');
        end case;
      end if;
    end process;

-- ----------------------------------------------------------------------------
--                        DATA CONNECTIONS
-- ----------------------------------------------------------------------------

    CODE_ADDR <= PC_REG;
    OUT_DATA <= DATA_RDATA;
    DATA_ADDR <= PTR_REG;
    DATA_WDATA <= MX_WDATA;

-- ----------------------------------------------------------------------------
--                       FINITE STATE MACHINE
-- ----------------------------------------------------------------------------

    fsm_processor: process(CLK, RESET, EN)
    begin
      if RESET = '1' then
        fsm_prev_state <= start;
        PC_RST <= '1';
        CNT_RST <= '1';
        PTR_RST <= '1';
      elsif CLK'event and CLK = '1' then
        if EN = '1' then
         fsm_prev_state <= fsm_state;
        end if;
      end if;
    end process;


    fsm_next_process: process (fsm_prev_state, OUT_BUSY, IN_VLD, CODE_DATA, CNT_REG, DATA_RDATA)
    begin
          OUT_WREN <= '0';
		      IN_REQ <= '0';
		      CODE_EN <= '0';
		      PC_INC <= '0';
		      PC_DEC <= '0';
		      PC_RST <= '0';
		      PTR_INC <= '0';
		      PTR_DEC <= '0';
		      PTR_RST <= '0';
	      	CNT_INC <= '0';
		      CNT_DEC <= '0';
		      CNT_RST <= '0';
		      MX_SEL <= "00";
	      	DATA_EN <= '0';
	      	DATA_WREN <= '0';
          case fsm_prev_state is
            when start => fsm_state <= ins;
            when ins =>
                  CODE_EN <= '1';
                  fsm_state <= decode;
            when decode =>
                  case CODE_DATA is
					              when X"3E" =>  fsm_state <= inc_state; -- > 
					              when X"3C" =>  fsm_state <= dec_state; -- < 
					              when X"2B" =>  fsm_state <= inc_state_0; -- + 
					              when X"2D" =>  fsm_state <= dec_state_0; -- - 
					              when X"5B" =>  fsm_state <= while_0; -- [ 
					              when X"5D" =>  fsm_state <= end_cycle_0; -- ] 
					              when X"2E" =>  fsm_state <= output_0; -- . 
					              when X"2C" =>  fsm_state <= input_0; -- , 
					              when X"7E" =>  fsm_state <= stop_cycle; -- ~ 
					              when X"00" =>  fsm_state <= null_state; -- null 
					              when others => fsm_state <= other_state; -- ostatné
				          end case;


            when inc_state =>
                PTR_INC <= '1';
                PC_INC <= '1';
                fsm_state <= ins;
            when dec_state =>
                PTR_DEC <= '1';
                PC_INC <= '1';
                fsm_state <= ins;


            when inc_state_0 =>
                DATA_EN <= '1';
                DATA_WREN <= '0';
                fsm_state <= inc_state_1;
            when inc_state_1 =>
                MX_SEL <= "01";
                fsm_state <= inc_state_2;
            when inc_state_2 =>
                DATA_EN <= '1';
                DATA_WREN <= '1';
                PC_INC <= '1';
                fsm_state <= ins;


            when dec_state_0 =>
                DATA_EN <= '1';
                DATA_WREN <= '0';
                fsm_state <= dec_state_1;
            when dec_state_1 =>
                MX_SEL <= "10";
                fsm_state <= dec_state_2;
            when dec_state_2 =>
                DATA_EN <= '1';
                DATA_WREN <= '1';
                PC_INC <= '1';
                fsm_state <= ins;


            when while_0 =>
                PC_INC <= '1';
				        DATA_EN <= '1';
				        DATA_WREN <= '0';
                fsm_state <= while_1;
            when while_1 =>
                if DATA_RDATA /= (DATA_RDATA'range => '0') then 
					        fsm_state <= ins;
				        else 
					        CNT_INC <= '1'; 
					        CODE_EN <= '1'; 
                  fsm_state <= while_2;
				        end if;
            when while_2 =>
                if CNT_REG = (CNT_REG'range => '0') then
                  fsm_state <= ins;
                else
                  if CODE_DATA = X"5B" then
                    CNT_INC <= '1';
                  elsif CODE_DATA = X"5D" then
                    CNT_DEC <= '1';
                  end if;
                  PC_INC <= '1';
                  fsm_state <= while_en;
                end if;
            when while_en =>
                CODE_EN <= '1'; 
                fsm_state <= while_2;
            

            when end_cycle_0 =>
				        DATA_EN <= '1';
				        DATA_WREN <= '0';
                fsm_state <= end_cycle_1;
            when end_cycle_1 =>
                if DATA_RDATA = (DATA_RDATA'range => '0') then 
                  PC_INC <= '1';
					        fsm_state <= ins;
				        else 
					        CNT_INC <= '1'; 
					        PC_DEC <= '1'; 
                  fsm_state <= end_cycle_en;
				        end if;
            when end_cycle_2 =>
                if CNT_REG = (CNT_REG'range => '0') then
                  fsm_state <= ins;
                else
                  if CODE_DATA = X"5D" then
                    CNT_INC <= '1';
                  elsif CODE_DATA = X"5B" then
                    CNT_DEC <= '1';
                  end if;
                  fsm_state <= end_cycle_3;
                end if;
            when end_cycle_3 =>
                if CNT_REG = (CNT_REG'range => '0') then 
				          	PC_INC <= '1';
				        else
					          PC_DEC <= '1'; 
				        end if;
				        fsm_state <= end_cycle_en;
            when end_cycle_en =>
				        CODE_EN <= '1';
                fsm_state <= end_cycle_2;


            when output_0 =>
                DATA_EN <= '1';
                DATA_WREN <= '0';
                fsm_state <= output_1;
            when output_1 =>
                if OUT_BUSY = '1' then
                    DATA_EN <= '1';
                    DATA_WREN <= '0';
                    fsm_state <=output_1;
                else
                    OUT_WREN <= '1';
                    PC_INC <= '1';
                    fsm_state <= ins;
                end if;


            when input_0 =>
                IN_REQ <= '1';
                MX_SEL <= "00";
                fsm_state <= input_1;
            when input_1 =>
                if IN_VLD /= '1' then
                    IN_REQ <= '1';
                    MX_SEL <= "00";
                    fsm_state <= input_1;
                else
                  DATA_EN <= '1';
                  DATA_WREN <= '1';
                  PC_INC <= '1';
                  fsm_state <= ins;
                end if;


            when stop_cycle =>
                CNT_INC <= '1';
                PC_INC <= '1';
                fsm_state <= stop_cycle_en;
            when stop_cycle_1 =>
                if CNT_REG = (CNT_REG'range => '0') then
                    fsm_state <= ins;
                else
                    if CODE_DATA = X"5B" then
                      CNT_INC <= '1';
                    elsif CODE_DATA = X"5D" then
                      CNT_DEC <= '1';
                    end if;
                end if;
            when stop_cycle_en =>
                CODE_EN <= '1';
                fsm_state <= stop_cycle_1;


            when null_state => fsm_state <= null_state;
            when other_state => null;
          end case;
    end process;
    

end behavioral;
 
