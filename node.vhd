LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- dans notre projet, nous avons choisi de mettre l'adresse en MSB et le message en LSB de la trame
-- lien = 9 bits: bit(8) = bit de reservation (idee IEEE 802.5), bits(7..0) = adresse & message

entity Node is
	generic( adr_cur: std_logic_vector(3 downto 0) := x"5";
	adr_dest: std_logic_vector(3 downto 0) := x"8";
	STARVE_THRESH: natural := 16   -- cycles d'attente du buffer TX avant de reserver un slot
	);
	port( CLK, TEST_IN, ENV_MESS: in std_logic;
	MESS_IN: in std_logic_vector (3 downto 0);
	TR_IN: in std_logic_vector (8 downto 0); -- trame= resv + adresse + message
	TEST_OK: out std_logic;
	BUSY: out std_logic; -- '1' tant que le buffer TX est plein: l'environnement doit maintenir/reessayer
	MESS_OUT: out std_logic_vector (3 downto 0);
	TR_OUT: out std_logic_vector (8 downto 0)
	);
end Node;

architecture archi_Node of Node is
alias RESV_TR_IN: std_logic is TR_IN(8);
alias ADR_TR_IN: std_logic_vector(3 downto 0) is TR_IN(7 downto 4);
alias MSG_TR_IN: std_logic_vector(3 downto 0) is TR_IN(3 downto 0);

signal TR_OUT_INT: std_logic_vector(8 downto 0) := '0' & x"F0";
signal TEST_OK_INT: std_logic := '0';
signal MESS_OUT_INT: std_logic_vector(3 downto 0) := (others => '0');

-- buffer TX 1 place: message local en attente d'un slot libre (adresse x"F" = buffer vide)
signal tx_buf: std_logic_vector(7 downto 0) := x"F0";

-- anti-famine (reservation de slot, idee 802.5):
--   starve_cnt compte les cycles ou tx_buf attend sans slot libre;
--   au seuil, le noeud marque (bit resv) une trame pleine qui passe et attend
--   le retour de ce slot: une fois la trame absorbee par sa destination, le slot
--   vide circule marque "reserve" et seul ce noeud a le droit de l'utiliser
signal starve_cnt: natural range 0 to 65535 := 0;
signal reserving: std_logic := '0';

begin
    -- Mappage des signaux internes aux ports de sortie
    TR_OUT <= TR_OUT_INT;
    TEST_OK <= TEST_OK_INT;
    MESS_OUT <= MESS_OUT_INT;
    BUSY <= '1' when tx_buf(7 downto 4) /= x"F" else '0';

    process(CLK)
    begin
        if rising_edge(clk) then

            TR_OUT_INT <= '0' & x"F0";
            MESS_OUT_INT <= (others => '0');

            -- test mode
	    ---- quand ce TR_OUT revient sur noeud courant: si TEST_IN =1, TEST_OK=1, sinon TEST_OK=0
            if TEST_IN = '1' then
                TR_OUT_INT <= '0' & adr_cur & x"C";

                if (ADR_TR_IN = adr_cur) and (MSG_TR_IN = x"C") then
                    TEST_OK_INT <= '1';
                else
                    TEST_OK_INT <= '0';
                end if;

            else
                TEST_OK_INT <= '0';

                -- trame en transit (valide, pas pour ce noeud): priorite absolue, le slot est occupe
                if ADR_TR_IN /= x"F" and ADR_TR_IN /= adr_cur then
                    TR_OUT_INT <= TR_IN;

                    -- injection impossible ce cycle: bufferiser le message local s'il y a la place
                    if ENV_MESS = '1' and tx_buf(7 downto 4) = x"F" then
                        tx_buf <= adr_dest & MESS_IN;
                    end if;
                    -- si tx_buf deja plein, le message est refuse (BUSY='1' previent l'environnement)

                    -- famine: le buffer attend, compter, et au seuil marquer une trame
                    -- pleine non deja reservee qui passe
                    if tx_buf(7 downto 4) /= x"F" then
                        if starve_cnt < STARVE_THRESH then
                            starve_cnt <= starve_cnt + 1;
                        elsif reserving = '0' and RESV_TR_IN = '0' then
                            TR_OUT_INT(8) <= '1';   -- reserver ce slot
                            reserving <= '1';
                        end if;
                    end if;

                -- slot libre: trame entrante vide, ou trame pour ce noeud (absorbee)
                else
                    -- si trame est pour ce noeud et pas trame test: delivrer
                    if ADR_TR_IN = adr_cur and MSG_TR_IN /= x"C" then
                        MESS_OUT_INT <= MSG_TR_IN;
                    end if;

                    -- slot reserve pour un AUTRE noeud: le faire circuler vide et marque,
                    -- interdiction d'y injecter (c'est ce qui borne l'attente du reserveur)
                    if RESV_TR_IN = '1' and reserving = '0' then
                        TR_OUT_INT <= '1' & x"F0";

                    -- ce noeud a une reservation en cours: il n'utilise QUE son slot reserve
                    -- (les slots libres ordinaires sont laisses aux autres noeuds)
                    elsif reserving = '1' then
                        if RESV_TR_IN = '1' then
                            TR_OUT_INT <= '0' & tx_buf;  -- consommer le slot reserve
                            tx_buf <= x"F0";
                            reserving <= '0';
                            starve_cnt <= 0;
                        end if;
                        -- sinon: laisser passer le slot libre ordinaire (TR_OUT reste vide)

                    -- remplir le slot libre: d'abord le message bufferise, sinon une injection directe
                    -- (un ENV_MESS pendant BUSY='1' n'est jamais accepte: l'environnement retient
                    --  son message et le presente a nouveau quand BUSY retombe)
                    elsif tx_buf(7 downto 4) /= x"F" then
                        TR_OUT_INT <= '0' & tx_buf;
                        tx_buf <= x"F0";
                        starve_cnt <= 0;
                    elsif ENV_MESS = '1' then
                        TR_OUT_INT <= '0' & adr_dest & MESS_IN;
                    end if;
                    -- sinon TR_OUT_INT garde sa valeur par defaut '0' & x"F0"
                end if;
            end if;
        end if;
    end process;
end archi_Node;
