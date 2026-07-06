#!/bin/bash
export CMAKE_BUILD_PARALLEL_LEVEL=4
exec /home/jiangzifeng/Software/android-sdk/cmake/3.22.1/bin/cmake "$@"
