#!/bin/bash
set -e

iverilog -Wall -g 2012 -s memory_tb -o memory_tb.sim \
memory_tb.v instruction_memory.v
./memory_tb.sim