LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.all; 

entity NODE_TB is
end entity NODE_TB;

architecture TB_ARC of NODE_TB is
    component Node
        generic (
            adr_cur  : std_logic_vector(3 downto 0) := x"5";
            adr_dest : std_logic_vector(3 downto 0) := x"8"
        );
        port (
            CLK, TEST_IN, ENV_MESS : in std_logic;
            MESS_IN                : in std_logic_vector (3 downto 0);
            TR_IN                  : in std_logic_vector (7 downto 0);
            TEST_OK                : out std_logic;
            MESS_OUT               : out std_logic_vector (3 downto 0);
            TR_OUT                 : out std_logic_vector (7 downto 0)
        );
    end component Node;

    -- const pour generic
    constant C_ADR_CURRENT  : std_logic_vector(3 downto 0) := x"5";
    constant C_ADR_DEFAULT  : std_logic_vector(3 downto 0) := x"8";

    -- signaux internes
    signal CLK_SIG       : std_logic := '0';
    signal TR_IN_SIG     : std_logic_vector(7 downto 0) := x"F0";
    signal TR_OUT_SIG    : std_logic_vector(7 downto 0);
    signal TEST_IN_SIG   : std_logic := '0';
    signal TEST_OK_SIG   : std_logic;
    signal ENV_MESS_SIG  : std_logic := '0';
    signal MESS_IN_SIG   : std_logic_vector(3 downto 0) := (others => '0');
    signal MESS_OUT_SIG  : std_logic_vector(3 downto 0);

    -- temps pr clk
    constant CLK_PERIOD : time := 10 ns;

    -- const trames de references (fig.2)
    constant FRAME_DEFAULT       : std_logic_vector(7 downto 0) := x"F0";
    constant FRAME_TEST          : std_logic_vector(7 downto 0) := x"5C";
    constant FRAME_DEST_8_MSG_3  : std_logic_vector(7 downto 0) := x"83";
    constant FRAME_OTHER_DEST_A1 : std_logic_vector(7 downto 0) := x"A1";
    constant FRAME_TO_SELF_MSG_A : std_logic_vector(7 downto 0) := x"5A";

begin

    UUT : Node
        generic map (
            adr_cur  => C_ADR_CURRENT,
            adr_dest => C_ADR_DEFAULT
        )
        port map (
            CLK        => CLK_SIG,
            TR_IN      => TR_IN_SIG,
            TR_OUT     => TR_OUT_SIG,
            TEST_IN    => TEST_IN_SIG,
            TEST_OK    => TEST_OK_SIG,
            ENV_MESS   => ENV_MESS_SIG,
            MESS_IN    => MESS_IN_SIG,
            MESS_OUT   => MESS_OUT_SIG
        );

    CLK_GEN : process
    begin
        loop
            CLK_SIG <= '0';
            wait for CLK_PERIOD / 2;
            CLK_SIG <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process CLK_GEN;

    STIMULI_GEN : process
    begin
        report "Début de la simulation (adr_cur=5, adr_dest=8)..." severity note;
        wait until rising_edge(CLK_SIG);
        
        -- etat init
        report "--- S0: Etat initial (Defaut) ---" severity note;
        TR_IN_SIG <= FRAME_DEFAULT;
        wait for 2 * CLK_PERIOD;
        
        -- test mode
	TEST_IN_SIG <= '1';
        wait for CLK_PERIOD; -- TR_OUT devrait être 5C
        
        -- Simuler retour imediat trame 5C
        TR_IN_SIG <= FRAME_TEST;
        wait for CLK_PERIOD; -- TEST_OK_SIG devrait etre '1'
        
        -- stop test mode
        TEST_IN_SIG <= '0';
        TR_IN_SIG <= FRAME_DEFAULT;
        wait for 2 * CLK_PERIOD; -- TEST_OK_SIG doit revenir a '0'
        
        ENV_MESS_SIG <= '1';
        MESS_IN_SIG <= x"3";
        wait for CLK_PERIOD; -- TR_OUT doit etre x"83"
        
        ENV_MESS_SIG <= '0';
        MESS_IN_SIG <= x"0";
        wait for 2 * CLK_PERIOD;
        
        TR_IN_SIG <= FRAME_OTHER_DEST_A1;
        wait for CLK_PERIOD; -- TR_OUT doit etre x"A1"
        
        wait for 2 * CLK_PERIOD;
        
        TR_IN_SIG <= FRAME_TO_SELF_MSG_A;
        wait for CLK_PERIOD; -- MESS_OUT_SIG doit etre x"A", TR_OUT doit etre x"F0"
        
        wait for 2 * CLK_PERIOD;
        
        TR_IN_SIG <= FRAME_DEFAULT;
        wait for 2 * CLK_PERIOD;
        
        wait; 
    end process STIMULI_GEN;
end architecture TB_ARC;