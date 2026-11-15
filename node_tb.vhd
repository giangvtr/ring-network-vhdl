LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.all; 

entity NODE_TB is
end entity NODE_TB;

architecture TB_ARC of NODE_TB is
    component Node
        generic (
            adr_cur       : std_logic_vector(3 downto 0) := x"5";
            adr_dest      : std_logic_vector(3 downto 0) := x"8";
            STARVE_THRESH : natural := 16
        );
        port (
            CLK, TEST_IN, ENV_MESS : in std_logic;
            MESS_IN                : in std_logic_vector (3 downto 0);
            TR_IN                  : in std_logic_vector (8 downto 0);
            TEST_OK                : out std_logic;
            BUSY                   : out std_logic;
            MESS_OUT               : out std_logic_vector (3 downto 0);
            TR_OUT                 : out std_logic_vector (8 downto 0)
        );
    end component Node;

    -- const pour generic
    constant C_ADR_CURRENT  : std_logic_vector(3 downto 0) := x"5";
    constant C_ADR_DEFAULT  : std_logic_vector(3 downto 0) := x"8";

    -- signaux internes
    -- seuil de famine reduit pour pouvoir tester la reservation rapidement (S8)
    constant C_STARVE_THRESH : natural := 4;

    signal CLK_SIG       : std_logic := '0';
    signal TR_IN_SIG     : std_logic_vector(8 downto 0) := '0' & x"F0";
    signal TR_OUT_SIG    : std_logic_vector(8 downto 0);
    signal TEST_IN_SIG   : std_logic := '0';
    signal TEST_OK_SIG   : std_logic;
    signal BUSY_SIG      : std_logic;
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
            adr_cur       => C_ADR_CURRENT,
            adr_dest      => C_ADR_DEFAULT,
            STARVE_THRESH => C_STARVE_THRESH
        )
        port map (
            CLK        => CLK_SIG,
            TR_IN      => TR_IN_SIG,
            TR_OUT     => TR_OUT_SIG,
            TEST_IN    => TEST_IN_SIG,
            TEST_OK    => TEST_OK_SIG,
            BUSY       => BUSY_SIG,
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
        report "D�but de la simulation (adr_cur=5, adr_dest=8)..." severity note;
        wait until rising_edge(CLK_SIG);
        
        -- etat init
        report "--- S0: Etat initial (Defaut) ---" severity note;
        TR_IN_SIG <= '0' & FRAME_DEFAULT;
        wait for 2 * CLK_PERIOD;
        
        -- test mode
	TEST_IN_SIG <= '1';
        wait for CLK_PERIOD; -- TR_OUT devrait �tre 5C
        
        -- Simuler retour imediat trame 5C
        TR_IN_SIG <= '0' & FRAME_TEST;
        wait for CLK_PERIOD; -- TEST_OK_SIG devrait etre '1'
        
        -- stop test mode
        TEST_IN_SIG <= '0';
        TR_IN_SIG <= '0' & FRAME_DEFAULT;
        wait for 2 * CLK_PERIOD; -- TEST_OK_SIG doit revenir a '0'
        
        ENV_MESS_SIG <= '1';
        MESS_IN_SIG <= x"3";
        wait for CLK_PERIOD; -- TR_OUT doit etre x"83"
        
        ENV_MESS_SIG <= '0';
        MESS_IN_SIG <= x"0";
        wait for 2 * CLK_PERIOD;
        
        TR_IN_SIG <= '0' & FRAME_OTHER_DEST_A1;
        wait for CLK_PERIOD; -- TR_OUT doit etre x"A1"
        
        wait for 2 * CLK_PERIOD;
        
        TR_IN_SIG <= '0' & FRAME_TO_SELF_MSG_A;
        wait for CLK_PERIOD; -- MESS_OUT_SIG doit etre x"A", TR_OUT doit etre x"F0"
        
        wait for 2 * CLK_PERIOD;
        
        TR_IN_SIG <= '0' & FRAME_DEFAULT;
        wait for 2 * CLK_PERIOD;

        -- --- S7: Collision injection / transit (buffer TX + BUSY) ---
        report "--- S7: ENV_MESS pendant une trame en transit ---" severity note;
        -- une trame en transit occupe le slot au moment ou on veut injecter x"7"
        TR_IN_SIG    <= '0' & FRAME_OTHER_DEST_A1;
        ENV_MESS_SIG <= '1';
        MESS_IN_SIG  <= x"7";
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        -- la trame en transit est retransmise, le message local est bufferise
        assert TR_OUT_SIG = '0' & FRAME_OTHER_DEST_A1
            report "S7a: la trame en transit doit etre retransmise" severity error;
        assert BUSY_SIG = '1'
            report "S7b: BUSY doit etre a 1 (message bufferise)" severity error;

        -- le message a ete accepte: l'environnement relache ENV_MESS; transit continue
        ENV_MESS_SIG <= '0';
        MESS_IN_SIG  <= x"0";
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        assert TR_OUT_SIG = '0' & FRAME_OTHER_DEST_A1
            report "S7c: transit toujours prioritaire" severity error;
        assert BUSY_SIG = '1'
            report "S7d: BUSY reste a 1 tant que le buffer n'est pas vide" severity error;

        -- un slot libre arrive: le message bufferise doit sortir (x"8" & x"7"), BUSY retombe
        TR_IN_SIG <= '0' & FRAME_DEFAULT;
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        assert TR_OUT_SIG = '0' & x"87"
            report "S7e: le message bufferise doit etre emis sur le slot libre" severity error;
        assert BUSY_SIG = '0'
            report "S7f: BUSY doit retomber apres emission du buffer" severity error;

        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        assert TR_OUT_SIG = '0' & FRAME_DEFAULT
            report "S7g: retour a la trame vide" severity error;

        -- --- S8: Famine -> reservation de slot (bit resv, idee 802.5) ---
        report "--- S8: famine puis reservation de slot ---" severity note;
        -- le buffer se charge (x"9") pendant un flux continu de trames en transit
        TR_IN_SIG    <= '0' & FRAME_OTHER_DEST_A1;
        ENV_MESS_SIG <= '1';
        MESS_IN_SIG  <= x"9";
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        ENV_MESS_SIG <= '0';
        MESS_IN_SIG  <= x"0";
        assert BUSY_SIG = '1'
            report "S8a: message bufferise pendant le transit" severity error;

        -- le transit sature le slot: apres STARVE_THRESH cycles d'attente,
        -- le noeud doit marquer (bit 8) une trame pleine qui passe
        for i in 1 to C_STARVE_THRESH + 1 loop
            wait until rising_edge(CLK_SIG);
        end loop;
        wait for 1 ns;
        assert TR_OUT_SIG = '1' & FRAME_OTHER_DEST_A1
            report "S8b: la trame qui passe doit etre marquee reservee" severity error;
        assert BUSY_SIG = '1'
            report "S8c: le buffer attend toujours" severity error;

        -- le slot reserve revient vide: seul ce noeud a le droit de le consommer
        TR_IN_SIG <= '1' & FRAME_DEFAULT;
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        assert TR_OUT_SIG = '0' & x"89"
            report "S8d: le message bufferise doit sortir sur le slot reserve" severity error;
        assert BUSY_SIG = '0'
            report "S8e: BUSY retombe apres consommation du slot reserve" severity error;

        -- un slot reserve pour un AUTRE noeud doit etre retransmis vide et marque, sans injection
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        assert TR_OUT_SIG = '1' & FRAME_DEFAULT
            report "S8f: un slot reserve pour un autre noeud doit circuler intact" severity error;

        TR_IN_SIG <= '0' & FRAME_DEFAULT;
        wait until rising_edge(CLK_SIG);
        wait for 1 ns;
        assert TR_OUT_SIG = '0' & FRAME_DEFAULT
            report "S8g: retour a la trame vide" severity error;

        report "Fin de la simulation node_tb" severity note;
        wait;
    end process STIMULI_GEN;
end architecture TB_ARC;