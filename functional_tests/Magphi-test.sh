#!/usr/bin/env bash

# 1. Parse command line arguments
# 2. cd to the test directory
# 3. run tests
# 4. Print summary of successes and failures, exit with 0 if
#    all tests pass, else exit with 1

# Uncomment the line below if you want more debugging information
# about this script.
#set -x

# The name of this test script
this_program_name="Magphi-test.sh"
# The program we want to test (either a full path to an executable, or the name of an executable in $PATH)
test_program=""
# Directory containing the test data files and expected outputs
test_data_dir=""
# Number of failed test cases
num_errors=0
# Total number of tests run
num_tests=0

function show_help {
cat << UsageMessage

${this_program_name}: run integration/regression tests for Magphi 

Usage:
    ${this_program_name} [-h] [-v] -p program -d test_data_dir 

Example:
    ${this_program_name} -p bin/Magphi -d data/tests

-h shows this help message

-v verbose output
UsageMessage
}

# echo an error message $1 and exit with status $2
function exit_with_error {
    printf "${this_program_name}: ERROR: $1\n"
    exit $2
}

# if -v is specified on the command line, print a more verbaose message to stdout
function verbose_message {
    if [ "${verbose}" = true ]; then
        echo "${this_program_name} $1"
    fi
}

# Parse the command line arguments and set the global variables program and test_data_dir 
function parse_args {
    local OPTIND opt

    while getopts "hp:d:v" opt; do
        case "${opt}" in
            h)
                show_help
                exit 0
                ;;
            p)  test_program="${OPTARG}"
                ;;
            d)  test_data_dir="${OPTARG}"
                ;;
            v)  verbose=true
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift

    if [[ -z ${test_program} ]]; then
        exit_with_error "missing command line argument: -p program, use -h for help" 2
    fi

    if [[ -z ${test_data_dir} ]]; then
        exit_with_error "missing command line argument: -d test_data_dir, use -h for help" 2
    fi
}


# Run a command and check that the output is
# exactly equal the contents of a specified file 
# ARG1: command we want to test as a string
# ARG2: a file path containing the expected output
# ARG3: expected exit status
function test_stdout_exit {
    let num_tests+=1
    output=$(eval $1)
    exit_status=$?
    expected_output_file=$2
    expected_exit_status=$3
    verbose_message "Testing stdout and exit status: $1"
    difference=$(diff <(echo "$output") $expected_output_file)
    if [ -n "$difference" ]; then 
        let num_errors+=1
        echo "Test output failed: $1"
        echo "Actual output:"
        echo "$output"
        expected_output=$(cat $2)
        echo "Expected output:"
        echo "$expected_output"
        echo "Difference:"
        echo "$difference"
    elif [ "$exit_status" -ne "$expected_exit_status" ]; then
        let num_errors+=1
        echo "Test exit status failed: $1"
        echo "Actual exit status: $exit_status"
        echo "Expected exit status: $expected_exit_status"
    fi 
}

# Run a command and check that the output file is
# exactly equal the contents of a specified file
# ARG1: A file returned from program after running
# ARG2: a file path containing the expected output
function test_output_file {
    let num_tests+=1
    output=$1
    expected_output_file=$2
    verbose_message "Testing output file: $1"
    difference=$(diff $output $expected_output_file)
    if [ -n "$difference" ]; then
        let num_errors+=1
        echo "Test output failed: $1"
        echo "Actual output:"
        echo "$output"
        expected_output=$(cat $2)
        echo "Expected output:"
        echo "$expected_output"
        echo "Difference:"
        echo "$difference"
    fi
}

# Run a command and check that the exit status is 
# equal to an expected value
# exactly equal the contents of a specified file 
# ARG1: command we want to test as a string
# ARG2: expected exit status
# NB: this is mostly for checking erroneous conditions, where the
# exact output message is not crucial, but the exit status is
# important
function test_exit_status {
    let num_tests+=1
    output=$(eval $1)
    exit_status=$?
    expected_exit_status=$2
    verbose_message "Testing exit status: $1"
    if [ "$exit_status" -ne "$expected_exit_status" ]; then
        let num_errors+=1
        echo "Test exit status failed: $1"
        echo "Actual exit status: $exit_status"
        echo "Expected exit status: $expected_exit_status"
    fi 
}


# 1. Parse command line arguments.
parse_args $@
# 2. Change to test directory
cd $test_data_dir
# 2. Run tests
## Test commandline exit status
# Test output for no no arguments
test_stdout_exit "$test_program" no_input.expected 2
# Test output for -help argument given
test_stdout_exit "$test_program -help" no_input.expected 0
# Test exit status for a bad command line invocation
test_exit_status "$test_program --this_is_not_a_valid_argument > /dev/null 2>&1" 2

## Check exit status for bad input GFF or FASTA files
# Test exit status when input is mixed fasta and gff
test_exit_status "$test_program -g test_fasta.fna test_GFF.gff -s empty_file > /dev/null 2>&1" 3
# Test exit status when fasta is mixed with random text file
test_exit_status "$test_program -g test_fasta.fna random_text.txt -s empty_file > /dev/null 2>&1" 3
# Test exit status when gff is mixed with random text file
test_exit_status "$test_program -g test_GFF.gff random_text.txt -s empty_file > /dev/null 2>&1" 3
# Test when just random text file is given
test_exit_status "$test_program -g random_text.txt -s empty_file > /dev/null 2>&1" 3
# Test when empty file is given as input
test_exit_status "$test_program -g empty_file -s empty_file > /dev/null 2>&1" 3

## TODO - funcitonal tests
# GENOMES - ALL As
# Fasta input
# Gff input
# gzipped inputs
#   - fasta
#   - gff
# All evidence levels
# A  - no hit (All G) - 0
# B  - single hit (All G with true primer) - 0
# C  - Multiple hit no overlap (low max distance, single contig multiple hits) - 1
# D  - Multiple hit multiple overlaps (large max distance, single contig multiple hits) - 2
# E  - Overlap and exclude seeds - 3
# F  - Separate contigs one at edge and exclude primers. - 3
# G  - Two seeds on separate contigs low max distance no connection - 5A
# H  - Two seeds on separate contigs with medium distance and connection (No annotation) - 5B
# I  - Two seeds on separate contigs with longer distance and connection (Annotations between) - 5C
# J  - Two seeds on same contig low max distance no overlap  - 6A
# K  - Two seeds on same contig medium max distance with overlap no annotations - 6B
# L  - Two seeds on same contig longer max distance with overlap with annotations - 6C


# Use the 'test_output_file'. First run a Magphi command with output into a specific folder, then test the output files one by one using the command.
Magphi -g evidence_levels_simple_genome.fasta -s no_primers_match_primers.fasta -o test_out_folder
test_output_file test_out_folder/master_primer_evidence.csv no_primers_match_evidence_levels.expected
# One with a primer on edge of contig and one that extracts
# Chaws problem.
# Run test where only one seed sequence can connect to a contig break, but the other can not connect to anything.



# 3. End of testing - check if any errors occurrred
if [ "$num_errors" -gt 0 ]; then
    echo "$test_program failed $num_errors out of $num_tests tests"
    exit 1
else
    echo "$test_program passed all $num_tests successfully"
    exit 0
fi
