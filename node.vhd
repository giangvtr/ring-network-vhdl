LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- dans notre projet, nous avons choisi de mettre l'adresse en MSB et le message en LSB de la trame

entity Node is 
	generic( adr_cur: std_logic_vector(3 downto 0) := x"5";
	adr_dest: std_logic_vector(3 downto 0) := x"8"
	);
	port( CLK, TEST_IN, ENV_MESS: in std_logic;
	MESS_IN: in std_logic_vector (3 downto 0);
	TR_IN: in std_logic_vector (7 downto 0); -- trame= adresse + message
	TEST_OK: out std_logic;
	BUSY: out std_logic; -- '1' tant que le buffer TX est plein: l'environnement doit maintenir/reessayer
	MESS_OUT: out std_logic_vector (3 downto 0);
	TR_OUT: out std_logic_vector (7 downto 0)
	);
end Node;

architecture archi_Node of Node is
alias ADR_TR_IN: std_logic_vector(3 downto 0) is TR_IN(7 downto 4);
alias MSG_TR_IN: std_logic_vector(3 downto 0) is TR_IN(3 downto 0);
alias ADR_TR_OUT: std_logic_vector(3 downto 0) is TR_OUT(7 downto 4);
alias MSG_TR_OUT: std_logic_vector(3 downto 0) is TR_OUT(3 downto 0);

signal TR_OUT_INT: std_logic_vector(7 downto 0) := x"F0";
signal TEST_OK_INT: std_logic := '0';
signal MESS_OUT_INT: std_logic_vector(3 downto 0) := (others => '0');

-- buffer TX 1 place: message local en attente d'un slot libre (adresse x"F" = buffer vide)
signal tx_buf: std_logic_vector(7 downto 0) := x"F0";

begin
    -- Mappage des signaux internes aux ports de sortie
    TR_OUT <= TR_OUT_INT;
    TEST_OK <= TEST_OK_INT;
    MESS_OUT <= MESS_OUT_INT;
    BUSY <= '1' when tx_buf(7 downto 4) /= x"F" else '0';

    process(CLK)
    begin
        if rising_edge(clk) then
            
            TR_OUT_INT <= x"F0";
            MESS_OUT_INT <= (others => '0');
            
            -- test mode
	    ---- quand ce TR_OUT revient sur noeud courant: si TEST_IN =1, TEST_OK=1, sinon TEST_OK=0
            if TEST_IN = '1' then
                TR_OUT_INT(7 downto 4) <= adr_cur;
                TR_OUT_INT(3 downto 0) <= x"C";

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

                -- slot libre: trame entrante vide, ou trame pour ce noeud (absorbee)
                else
                    -- si trame est pour ce noeud et pas trame test: delivrer
                    if ADR_TR_IN = adr_cur and MSG_TR_IN /= x"C" then
                        MESS_OUT_INT <= MSG_TR_IN;
                    end if;

                    -- remplir le slot libre: d'abord le message bufferise, sinon une injection directe
                    -- (un ENV_MESS pendant BUSY='1' n'est jamais accepte: l'environnement retient
                    --  son message et le presente a nouveau quand BUSY retombe)
                    if tx_buf(7 downto 4) /= x"F" then
                        TR_OUT_INT <= tx_buf;
                        tx_buf <= x"F0";
                    elsif ENV_MESS = '1' then
                        TR_OUT_INT(7 downto 4) <= adr_dest;
                        TR_OUT_INT(3 downto 0) <= MESS_IN;
                    end if;
                    -- sinon TR_OUT_INT garde sa valeur par defaut x"F0"
                end if;
            end if;
        end if;
    end process;
end archi_Node;