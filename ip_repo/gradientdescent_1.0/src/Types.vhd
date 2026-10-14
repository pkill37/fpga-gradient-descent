library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

package Types is
    constant WORD_SIZE : integer := 32;
    type vector is array (integer range <>) of std_logic_vector(WORD_SIZE-1 downto 0);
    type matrix is array (integer range<>, integer range<>) of std_logic_vector(WORD_SIZE-1 downto 0);
    
    function element_divide(a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
    function element_multiply(a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
    function element_add(a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
    function element_subtract(a: std_logic_vector; b: std_logic_vector) return std_logic_vector;
end package;

package body Types is
    function element_divide(a: std_logic_vector; b: std_logic_vector) return std_logic_vector is variable c : std_logic_vector(WORD_SIZE-1 downto 0);
    begin
        c := std_logic_vector(signed(a) / signed(b));
        return c;
    end element_divide;
    
    function element_multiply(a: std_logic_vector; b: std_logic_vector) return std_logic_vector is variable c : std_logic_vector(WORD_SIZE-1 downto 0);
        variable tmp1 : std_logic_vector(63 downto 0);
    begin
        tmp1 := std_logic_vector(signed(a)*signed(b));
        tmp1 := std_logic_vector(shift_right(signed(tmp1), 11)); -- division by the scaling factor 
        c := std_logic_vector(resize(signed(tmp1), WORD_SIZE));
        return c;
    end element_multiply;
    
    function element_add(a: std_logic_vector; b: std_logic_vector) return std_logic_vector is variable c : std_logic_vector(WORD_SIZE-1 downto 0);
    begin
        c := std_logic_vector(signed(a) + signed(b));
        return c;
    end element_add;
    
    function element_subtract(a: std_logic_vector; b: std_logic_vector) return std_logic_vector is variable c : std_logic_vector(WORD_SIZE-1 downto 0);
    begin
        c := std_logic_vector(signed(a) - signed(b));
        return c;
    end element_subtract;
end package body;