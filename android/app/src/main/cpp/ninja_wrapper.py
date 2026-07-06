#!/usr/bin/env python3
import subprocess
import sys

args = list(sys.argv[1:])
has_j = False
new_args = []
i = 0
while i < len(args):
    arg = args[i]
    if arg == "-j":
        new_args.append("-j4")
        has_j = True
    elif arg.startswith("-j"):
        num = arg[2:]
        if num:
            j_val = min(int(num), 4)
            new_args.append(f"-j{j_val}")
            has_j = True
        else:
            new_args.append("-j4")
            has_j = True
    else:
        new_args.append(arg)
    i += 1

if not has_j:
    new_args.insert(1, "-j4")

result = subprocess.run(["/home/jiangzifeng/Software/android-sdk/cmake/3.22.1/bin/ninja"] + new_args)
sys.exit(result.returncode)
