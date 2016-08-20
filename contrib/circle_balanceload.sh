#!/bin/bash
# Balance the testing load between 3 CircleCI parallel containers

tests=($(julia -e 'include("choosetests.jl"); t = unique(map(s -> split(s, "/")[1], choosetests(["all"])[1])); print(join(t, " "))'))

# Command to run tests -- append names for specific tests
jlcmd="/tmp/julia/bin/julia --check-bounds=yes runtests.jl"

# The point at which we cut the tests between workers 1 and 2 (0 always gets linalg)
cutoff=23

case $CIRCLE_NODE_INDEX in
  0) $jlcmd ${tests[0]} ;;
  1) $jlcmd ${tests[@]:1:${cutoff}} ;;
  2) $jlcmd ${tests[@]:${cutoff}+1} fft dsp examples ;;
esac
