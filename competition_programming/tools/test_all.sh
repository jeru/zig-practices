#!/bin/bash
set -e

VERIFIER="${VERIFIER:-DIFF}"
binary="$1"
test_dir="$2"

verify() {
    if [[ "X${VERIFIER}" = "XDIFF" ]] then
        diff -q _test/out "${1}.ans" 
    else
        "${VERIFIER}" "${1}.in" _test/out "${1}.ans"
    fi
}

test_one() {
    local f="$1"
    echo "======================="
    echo "Testing: $f"
    mkdir -p _test
    rm -rf _test/out
    time "$binary" < "${f}.in" > _test/out

    verify "$f" && echo "Okay" || { echo "DIFFERENT!!!"; exit 1; }
}

for f in $(ls $test_dir/*.in); do
    test_one $(echo $f | sed 's/\.in$//')
done

echo
echo
echo "Congratulations! All correct."
