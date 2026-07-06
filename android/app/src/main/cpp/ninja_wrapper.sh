#!/bin/bash
exec nice -n 10 /home/jiangzifeng/Software/android-sdk/cmake/3.22.1/bin/ninja -j4 "$@"
