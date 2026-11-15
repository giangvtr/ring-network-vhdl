LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE data_types IS
	SUBTYPE size is natural range 2 to 4;
	-- tableau de nibbles non contraint: dimensionne par le port/signal qui l'utilise
	TYPE nibble_array IS array (natural range <>) of std_logic_vector(3 downto 0);
END data_types;


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.data_types.ALL;

ENTITY network IS
GENERIC(
	N: size := 3); 	-- size of the network

PORT(
	clk: in std_logic;
	-- chaque noeud de l'anneau (indice = position sur l'anneau, cf. border_index)
	-- est une interface reseau complete
	Test_in:  in  std_logic_vector(0 to 4*N-5);
	Env_mes:  in  std_logic_vector(0 to 4*N-5);
	Test_ok:  out std_logic_vector(0 to 4*N-5);
	Busy:     out std_logic_vector(0 to 4*N-5);
	Mess_in:  in  nibble_array(0 to 4*N-5);
	Mess_out: out nibble_array(0 to 4*N-5)
);
END ENTITY network;


architecture ring3 of network is
	constant total_node: natural := 4*N - 4;
	type link_array is array (0 to total_node-1) of std_logic_vector(7 downto 0);   --contient des trames 8 bits

	--Question 4: adresse mapping
	type addr_array is array(0 to 3, 0 to 3) of std_logic_vector(3 downto 0);
	constant ADDR_MAP : addr_array := (
		(b"0000", b"0001", b"0011", b"0100"),
		(b"1100", b"0010", b"0100", b"0101"),
		(b"1011", b"0110", b"0101", b"0110"),
		(b"1010", b"1001", b"1000", b"0111")
	);

	signal trin_mat: link_array;
	signal trout_mat: link_array;


	-- DEBUG SIGNALSSSSS ================
    	type addr_array_debug is array (0 to total_node-1) of std_logic_vector(3 downto 0);
    	signal debug_adr_cur: addr_array_debug := (others => x"F");
    	signal debug_adr_dest: addr_array_debug := (others => x"F");
	-- ==================================

	-- Function to map 2D into 1D array
	function border_index (row,col: integer) return integer is
	begin
		-- top row: left to right
		if row = 0 then
			return col;
		-- right column: top to bottom
		elsif col = N-1 then
			return (N-1) + row;

		-- bottom
		elsif row = N-1 then
			return (N-1) + (N-1) + (N-1-col);   -- upper side + right side + index on the bottom row

		-- left col
		else
			return (N-1) + (N-1) + (N-1) + (N-1-row); -- sum of 3 sides index + index on the left column
		end if;
	end function;

	-- GENERATE NODES
begin
	-- Generate 2D grid
	gen_i: for i in 0 to N-1 generate
    	gen_j: for j in 0 to N-1 generate

	-- Only keep nodes on the border of this grid
	is_border: if (i=0) or (i=N-1) or (j=0) or (j = N-1) generate
		constant index: integer := border_index(i,j);
		begin
		debug_adr_cur(index) <= ADDR_MAP(i, j);
                debug_adr_dest(index) <= ADDR_MAP(N-1-i, N-1-j);

		-- chaque noeud du bord est une interface reseau complete, cablee sur les ports tableaux
		Node_inst: entity work.Node
		generic map (
			adr_cur => ADDR_MAP(i,j),
			adr_dest => ADDR_MAP(N-1-i, N-1-j)
		)
		port map(
			CLK => clk,
			TR_IN => trin_mat(index),
			TR_OUT => trout_mat(index),

			TEST_IN => Test_in(index),
			TEST_OK => Test_ok(index),

			ENV_MESS => Env_mes(index),
			BUSY => Busy(index),

			MESS_IN => Mess_in(index),
			MESS_OUT => Mess_out(index)
		);
	end generate is_border;
	end generate gen_j;
	end generate gen_i;

	ring_connect: for k in 0 to total_node-2 generate
    		trin_mat(k+1) <= trout_mat(k);                       --the input of the second node is from out first node
	end generate ring_connect;

	trin_mat(0) <= trout_mat(total_node-1);                      -- handle the first and last node since the index is chelou
end ring3;
