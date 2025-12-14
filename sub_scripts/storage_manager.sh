#!/bin/bash
/bin/snapraid sync -c /etc/snapraid.conf
/bin/snapraid scrub -p 1 -o 14 -c /etc/snapraid.conf
/bin/snapraid -e fix -c /etc/snapraid.conf
