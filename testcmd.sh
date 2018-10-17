#!/bin/bash

# this simple test script is used as an example command

PERIOD=0.5
sleep $PERIOD
echo "child stdout #1"

sleep $PERIOD
echo "child stdout #2"

sleep $PERIOD
echo "child warning message on stderr" >&2

sleep $PERIOD
echo "child stdout #3"

sleep $PERIOD
echo "child prompts for input:"

sleep $PERIOD
read SOME_INPUT

sleep $PERIOD
echo "child received input='$SOME_INPUT'"


sleep $PERIOD
echo "child exiting with code=42"
exit 42
