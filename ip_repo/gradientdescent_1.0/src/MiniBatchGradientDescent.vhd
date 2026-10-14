library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.Types.all;

entity MiniBatchGradientDescent is
    generic(
        m: integer;
        n: integer
    );
    port(
        X         : in matrix(m-1 downto 0, n-1 downto 0);
        Y         : in vector(m-1 downto 0);
        theta     : in vector(n-1 downto 0);
        alpha     : in std_logic_vector(WORD_SIZE-1 downto 0);
        theta_new : out vector(n-1 downto 0)
    );
end MiniBatchGradientDescent;

architecture Behavioral of MiniBatchGradientDescent is
    signal s_Xt         : matrix(n-1 downto 0, m-1 downto 0);
    signal s_h          : vector(m-1 downto 0);
    signal s_error      : vector(m-1 downto 0);
    signal s_tmp1       : vector(n-1 downto 0);
    signal s_tmp2       : vector(n-1 downto 0);
    signal s_scalar     : std_logic_vector(WORD_SIZE-1 downto 0);
begin
    s_scalar <= element_divide(alpha, std_logic_vector(to_signed(m, 32)));
    
    h: entity work.matrix_multiply_by_vector(Behavioral)
    generic map(
        m => m,
        n => n
    )
    port map(
        a => X,
        b => theta,
        c => s_h
    );
    
    
    e: entity work.vector_subtract(Behavioral)
    generic map(
        m => m
    )
    port map(
        a => s_h,
        b => Y,
        c => s_error
    );

    t: entity work.matrix_transpose(Behavioral)
    generic map(
        m => m,
        n => n
    )
    port map(
        a => X,
        c => s_Xt
    );
    
    t1: entity work.matrix_multiply_by_vector(Behavioral)
    generic map(
        m => n,
        n => m
    )
    port map(
        a => s_Xt,
        b => s_error,
        c => s_tmp1
    );
    
    
    t2: entity work.vector_multiply_by_scalar(Behavioral)
    generic map(
        m => n
    )
    port map(
        a => s_tmp1,
        scalar => s_scalar,
        c => s_tmp2
    );
    
    l_theta_new: entity work.vector_subtract(Behavioral)
    generic map(
        m => n
    )
    port map(
        a => theta,
        b => s_tmp2,
        c => theta_new
    );
end Behavioral;