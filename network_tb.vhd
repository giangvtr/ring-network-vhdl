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

    -- Parametres specifiques au reseau 3x3
    constant N_TOT_NODES : integer := 4*N_PARAM - 4; -- 8 noeuds au total

    -- indices sur l'anneau (cf. border_index dans network.vhd)
    constant IDX_HG : integer := 0;               -- noeud Haut-Gauche (adresse 0)
    constant IDX_BD : integer := 4;               -- noeud Bas-Droite  (adresse 5)

    component Network
        generic (
            N : size
        );
        port (
            CLK      : in  std_logic;
            Test_in  : in  std_logic_vector(0 to 4*N-5);
            Env_mes  : in  std_logic_vector(0 to 4*N-5);
            Test_ok  : out std_logic_vector(0 to 4*N-5);
            Busy     : out std_logic_vector(0 to 4*N-5);
            Mess_in  : in  nibble_array(0 to 4*N-5);
            Mess_out : out nibble_array(0 to 4*N-5)
        );
    end component Network;

    -- Signaux internes
    signal CLK_SIG      : std_logic := '0';
    constant CLK_PERIOD : time := 10 ns;

    signal Test_in_SIG  : std_logic_vector(0 to N_TOT_NODES-1) := (others => '0');
    signal Env_mes_SIG  : std_logic_vector(0 to N_TOT_NODES-1) := (others => '0');
    signal Test_ok_SIG  : std_logic_vector(0 to N_TOT_NODES-1);
    signal Busy_SIG     : std_logic_vector(0 to N_TOT_NODES-1);
    signal Mess_in_SIG  : nibble_array(0 to N_TOT_NODES-1) := (others => (others => '0'));
    signal Mess_out_SIG : nibble_array(0 to N_TOT_NODES-1);

begin

    -- 1. Instanciation du composant Network (DUT)
    UUT : Network
        generic map (
            N => N_PARAM
        )
        port map (
            CLK      => CLK_SIG,
            Test_in  => Test_in_SIG,
            Env_mes  => Env_mes_SIG,
            Test_ok  => Test_ok_SIG,
            Busy     => Busy_SIG,
            Mess_in  => Mess_in_SIG,
            Mess_out => Mess_out_SIG
        );

    -- 2. Generation de l'Horloge
    CLK_GEN : process
    begin
        loop
            CLK_SIG <= '0';
            wait for CLK_PERIOD / 2;
            CLK_SIG <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process CLK_GEN;

    -- 3. Generation des Stimuli pour les tests
    STIMULI_GEN : process
        -- tour complet de l'anneau: 1 cycle pour l'emission + N_TOT_NODES hops
        -- + 1 cycle pour que TEST_OK soit registre et lisible apres le front
        constant RING_DELAY_FULL : integer := N_TOT_NODES + 2;

        -- H-G vers B-D
        constant RING_DELAY_HG_BD : integer := N_TOT_NODES / 2 + 1;
    begin
        wait until rising_edge(CLK_SIG);

        -- A. Test Noeud H-G (Adresse 0)
        Test_in_SIG(IDX_HG) <= '1';

	-- attend que le signal parcourt le reseau
	for i in 1 to RING_DELAY_FULL loop
             wait until rising_edge(CLK_SIG);
        end loop;

        -- Verification
        if Test_ok_SIG(IDX_HG) = '1' then
            report "H-G Test OK" severity note;
        else
            report "H-G Test FAILED" severity error;
        end if;

        Test_in_SIG(IDX_HG) <= '0';
        wait for 2 * CLK_PERIOD;

        -- B. Test Noeud B-D (Adresse 5)
        Test_in_SIG(IDX_BD) <= '1';

	-- attend que le signal parcourt le reseau
        for i in 1 to RING_DELAY_FULL loop
             wait until rising_edge(CLK_SIG);
        end loop;

        -- Verification
        if Test_ok_SIG(IDX_BD) = '1' then
            report "B-D Test OK" severity note;
        else
            report "B-D Test FAILED" severity error;
        end if;

        Test_in_SIG(IDX_BD) <= '0';
        wait for 2 * CLK_PERIOD;

        -- C. Envoi de message H-G -> B-D (0 -> 5)
        report "--- Test C: Envoi Message 0 -> 5 (Msg D) ---" severity note;
        Env_mes_SIG(IDX_HG) <= '1';
        Mess_in_SIG(IDX_HG) <= x"D";

        wait for 4*N_TOT_NODES*CLK_PERIOD;

        Env_mes_SIG(IDX_HG) <= '0';

        -- Attendre que la trame arrive au noeud en bas a droite
        for i in 1 to RING_DELAY_HG_BD loop
             wait until rising_edge(CLK_SIG);
        end loop;

        -- Verification Mess_out du noeud B-D
        if Mess_out_SIG(IDX_BD) = x"D" then
            report "Message recu correctement sur Mess_out(B-D) (D)" severity note;
        else
            report "Erreur : Message recu sur Mess_out(B-D) incorrect (attendu D)" severity error;
        end if;

	-- D. Envoi de message B-D -> H-G (5 -> 0)

	report "--- Test D: Envoi Message 5 -> 0 (Msg A) ---" severity note;
        Env_mes_SIG(IDX_BD) <= '1';
        Mess_in_SIG(IDX_BD) <= x"A";

        wait for 4*N_TOT_NODES*CLK_PERIOD;

        Env_mes_SIG(IDX_BD) <= '0';

        -- Attendre que la trame arrive au noeud en haut a gauche
        for i in 1 to RING_DELAY_HG_BD loop
             wait until rising_edge(CLK_SIG);
        end loop;

        -- Verification Mess_out du noeud H-G
        if Mess_out_SIG(IDX_HG) = x"A" then
            report "Message recu correctement sur Mess_out(H-G) (A)" severity note;
        else
            report "Erreur : Message recu sur Mess_out(H-G) incorrect (attendu A)" severity error;
        end if;

        wait;

    end process STIMULI_GEN;

end architecture TB_ARC;
