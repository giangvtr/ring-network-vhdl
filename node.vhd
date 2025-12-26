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

begin
    -- Mappage des signaux internes aux ports de sortie
    TR_OUT <= TR_OUT_INT;
    TEST_OK <= TEST_OK_INT;
    MESS_OUT <= MESS_OUT_INT;

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

                -- si trame valide
                if ADR_TR_IN /= x"F" then
                    
                    -- si trame est pour ce n?ud
                    if ADR_TR_IN = adr_cur then

			-- si pas trame test
                        if MSG_TR_IN /= x"C" then
                            MESS_OUT_INT <= MSG_TR_IN;
                            TR_OUT_INT <= x"F0";
                        else
                            TR_OUT_INT <= x"F0";
                        end if;
                    else 
                        TR_OUT_INT <= TR_IN;
                    end if;
                elsif ENV_MESS = '1' then
                    TR_OUT_INT(7 downto 4) <= adr_dest;
                    TR_OUT_INT(3 downto 0) <= MESS_IN;
                
                -- default mode
                else
                    TR_OUT_INT <= x"F0";
                end if;
            end if;
        end if;
    end process;
end archi_Node;