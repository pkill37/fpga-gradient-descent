#!/bin/sh
set -ex
export PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:$PERL5LIB}"

cd ip_repo/gradientdescent_1.0

ghdl -a --std=08 \
  src/Types.vhd \
  src/matrix_transpose.vhd \
  src/vector_subtract.vhd \
  src/vector_multiply_by_scalar.vhd \
  src/matrix_multiply_by_vector.vhd \
  src/MiniBatchGradientDescent.vhd \
  src/gradientdescent_testbench.vhd

ghdl -e --std=08 MiniBatchGradientDescentTest
ghdl -r --std=08 MiniBatchGradientDescentTest --vcd=sim.vcd
surfer "$PWD/sim.vcd"
