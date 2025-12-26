-- network_tb.vhd (Question 5)

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.all; 
USE work.data_types.ALL;

entity NETWORK_TB is
end entity NETWORK_TB;

architecture TB_ARC of NETWORK_TB is

    constant N_PARAM : size := 3; 
    
    component Network
        generic (
            N : size
        );
        port (
            CLK        : in  std_logic;
            Test_in1   : in  std_logic;
            Test_ok1   : out std_logic;
            Env_mes1   : in  std_logic;
            Mess_in1   : in  std_logic_vector(3 downto 0);
            Mess_out1  : out std_logic_vector(3 downto 0);
            Test_in2   : in  std_logic;
            Test_ok2   : out std_logic;
            Env_mes2   : in  std_logic;
            Mess_in2   : in  std_logic_vector(3 downto 0);
            Mess_out2  : out std_logic_vector(3 downto 0)
        );
    end component Network;

    -- Paramètres spécifiques au réseau 3x3
    constant N_TOT_NODES : integer := 4*N_PARAM - 4; -- 8 n?uds au total
    
    -- Signaux internes
    signal CLK_SIG       : std_logic := '0';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Ports externes N?ud H-G (1)
    signal Test_in1_SIG  : std_logic := '0';
    signal Test_ok1_SIG  : std_logic;
    signal Env_mes1_SIG  : std_logic := '0';
    signal Mess_in1_SIG  : std_logic_vector(3 downto 0) := (others => '0');
    signal Mess_out1_SIG : std_logic_vector(3 downto 0);
    
    -- Ports externes N?ud B-D (2)
    signal Test_in2_SIG  : std_logic := '0';
    signal Test_ok2_SIG  : std_logic;
    signal Env_mes2_SIG  : std_logic := '0';
    signal Mess_in2_SIG  : std_logic_vector(3 downto 0) := (others => '0');
    signal Mess_out2_SIG : std_logic_vector(3 downto 0);

begin

    -- 1. Instanciation du composant Network (DUT)
    UUT : Network
        generic map (
            N => N_PARAM
        )
        port map (
            CLK        => CLK_SIG,
            Test_in1   => Test_in1_SIG,
            Test_ok1   => Test_ok1_SIG,
            Env_mes1   => Env_mes1_SIG,
            Mess_in1   => Mess_in1_SIG,
            Mess_out1  => Mess_out1_SIG,
            Test_in2   => Test_in2_SIG,
            Test_ok2   => Test_ok2_SIG,
            Env_mes2   => Env_mes2_SIG,
            Mess_in2   => Mess_in2_SIG,
            Mess_out2  => Mess_out2_SIG
        );

    -- 2. Génération de l'Horloge
    CLK_GEN : process
    begin
        loop
            CLK_SIG <= '0';
            wait for CLK_PERIOD / 2;
            CLK_SIG <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process CLK_GEN;

    -- 3. Génération des Stimuli pour les tests
    STIMULI_GEN : process
        -- tour complet de l'anneau 
        constant RING_DELAY_FULL : integer := N_TOT_NODES + 1; 
        
        -- H-G vers B-D
        constant RING_DELAY_HG_BD : integer := N_TOT_NODES / 2 + 1;
    begin
        wait until rising_edge(CLK_SIG);
        
        -- A. Test Noeud H-G (Adresse 0, Test_in1)
        Test_in1_SIG <= '1';		
        
	-- attend que le signal parcourt le reseau
	for i in 1 to RING_DELAY_FULL loop
             wait until rising_edge(CLK_SIG);
        end loop;
        
        -- Verification
        if Test_ok1_SIG = '1' then
            report "H-G Test OK" severity note;
        else
            report "H-G Test FAILED" severity error;
        end if;
        
        Test_in1_SIG <= '0';
        wait for 2 * CLK_PERIOD;	-- test a corriger car ne passe pas
        
        -- B. Test Noeud B-D (Adresse 5, Test_in2)
        Test_in2_SIG <= '1';
	
	-- attend que le signal parcourt le reseau
        for i in 1 to RING_DELAY_FULL loop
             wait until rising_edge(CLK_SIG);
        end loop;
        
        -- Verification
        if Test_ok2_SIG = '1' then
            report "B-D Test OK" severity note;
        else
            report "B-D Test FAILED" severity error;
        end if;
        
        Test_in2_SIG <= '0';
        wait for 2 * CLK_PERIOD;
        
        -- C. Envoi de message H-G -> B-D (0 -> 5)
        report "--- Test C: Envoi Message 0 -> 5 (Msg D) ---" severity note;
        Env_mes1_SIG <= '1';
        Mess_in1_SIG <= x"D";
        
        wait for 4*N_TOT_NODES*CLK_PERIOD; 
        
        Env_mes1_SIG <= '0';
        
        -- Attendre que la trame arrive au noeud en bas a droite
        for i in 1 to RING_DELAY_HG_BD loop
             wait until rising_edge(CLK_SIG);
        end loop; 

        -- Verification Mess_out2
        if Mess_out2_SIG = x"D" then
            report "Message recu correctement sur Mess_out2 (D)" severity note;
        else
            report "Erreur : Message recu sur Mess_out2 incorrect (attendu D)" severity error;
        end if;
        
	-- D. Envoi de message B-D -> H-G (5 -> 0)

	report "--- Test D: Envoi Message 5 -> 0 (Msg A) ---" severity note;
        Env_mes2_SIG <= '1';
        Mess_in2_SIG <= x"A";
        
        wait for 4*N_TOT_NODES*CLK_PERIOD; 
        
        Env_mes1_SIG <= '0';
        
        -- Attendre que la trame arrive au noeud en bas a droite
        for i in 1 to RING_DELAY_HG_BD loop
             wait until rising_edge(CLK_SIG);
        end loop; 

        -- Verification Mess_out1
        if Mess_out1_SIG = x"A" then
            report "Message recu correctement sur Mess_out1 (A)" severity note;
        else
            report "Erreur : Message recu sur Mess_out1 incorrect (attendu A)" severity error;
        end if;

        wait; 

    end process STIMULI_GEN;

end architecture TB_ARC;