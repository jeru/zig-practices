#!/bin/bash
set -e

binary="$1"
test_dir="$2"

test_one() {
    local f="$1"
    echo "======================="
    echo "Testing: $f"
    mkdir -p _test
    rm -rf _test/out
    time "$binary" < "${f}.in" > _test/out
    diff -q _test/out "${f}.ans" && echo "Okay" || { echo "DIFFERENT!!!"; exit 1; }
}

for f in $(ls $test_dir/*.in); do
    test_one $(echo $f | sed 's/\.in$//')
done

echo
echo
echo "Congratulations! All correct."
