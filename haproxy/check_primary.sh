#!/bin/bash
VALUE=$(
    /usr/bin/psql -t -h "$3" -p "$4" -c "select pg_is_in_recovery()" -X -A -U postgres "dbname=template1"
)

if [ "$VALUE" == "t" ]
then
    # echo "$0: $3:$4 - standby"
    exit 1
elif [ "$VALUE" == "f" ]
then
    # echo "$0: $3:$4 - primary"
    exit 0
else
    echo "$0: $3:$4 - error"
    exit 255
fi