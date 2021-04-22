#!/bin/bash

## Fix the permissions of data that has been transferred through Globus such that
## all folders and files within the directories specified as arguments have
## 770 and 660 permission, respectively.

USAGE="Usage: $0 dir1 dir2 ... dirN"

if [ "$#" = "0" ]; then
	echo "$USAGE"
	exit 1
fi

while (( "$#" > 0 )); do

echo "Fixing perms in $1"

# Using straight chmod
chmod -R u=rwX,g=rwX,o-rwx "$1"

## Using find
# find "$1" -type d -exec chmod 770 '{}' \;
# find "$1" -type f -exec chmod 660 '{}' \;

## Using find (faster?) and filtering by userid
# find "$1" -type d -user ${USER} -print0 | xargs -0 chmod 770
# find "$1" -type f -user ${USER} -print0 | xargs -0 chmod 660

shift
done

echo "Done!"
