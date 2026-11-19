-- Wrapper cocotb: le VPI de GHDL n'expose pas les tableaux de vecteurs
-- (nibble_array), donc on aplatit Mess_in/Mess_out en un seul std_logic_vector.
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE work.data_types.ALL;

entity network_cocotb is
	generic( N: size := 3 );
	port(
		clk: in std_logic;
		test_in: in std_logic_vector(0 to 4*N-5);
		env_mes: in std_logic_vector(0 to 4*N-5);
		test_ok: out std_logic_vector(0 to 4*N-5);
		busy: out std_logic_vector(0 to 4*N-5);
		mess_in_flat: in std_logic_vector(0 to 4*(4*N-4)-1);
		mess_out_flat: out std_logic_vector(0 to 4*(4*N-4)-1)
	);
end entity network_cocotb;

architecture wrap of network_cocotb is
	constant NT: natural := 4*N - 4;
	signal mi, mo: nibble_array(0 to NT-1);
begin
	g_flat: for i in 0 to NT-1 generate
		mi(i) <= mess_in_flat(4*i to 4*i+3);
		mess_out_flat(4*i to 4*i+3) <= mo(i);
	end generate;

	u_net: entity work.network
		generic map( N => N )
		port map(
			clk => clk,
			Test_in => test_in,
			Env_mes => env_mes,
			Test_ok => test_ok,
			Busy => busy,
			Mess_in => mi,
			Mess_out => mo
		);
end architecture wrap;
