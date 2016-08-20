#!/bin/bash
# Balance the testing load between 4 CircleCI parallel containers

tests=($(julia -e 'include("choosetests.jl"); t = choosetests(["all"])[1]; print(join(t, " "))'))

# Command to run tests -- append names for specific tests
jlcmd="/tmp/julia/bin/julia --check-bounds=yes runtests.jl"

# There are 23 linear algebra tests. Divide them between the first two containers.
cut1=11

# That leaves 106 other tests. Try dividing them into one small and one large group.
cut2=35

case $CIRCLE_NODE_INDEX in
  0) $jlcmd ${tests[@]:0:${cut1}} ;;
  1) $jlcmd ${tests[@]:${cut1}+1:23} ;;
  2) $jlcmd ${tests[@]:24:${cut2}} ;;
  3) $jlcmd ${tests[@]:${cut2}+1} ;;
esac
