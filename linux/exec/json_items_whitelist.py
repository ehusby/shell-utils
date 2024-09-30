#!/usr/bin/env python

import json
import sys

whitelist_pairs = [
    tuple(item.strip().strip('"') for item in line.strip().rstrip(",").split(":", 1))
    for line in sys.stdin.readlines()
]

json_obj = json.load(open(sys.argv[1], "r"))

keep_json_item_list = []
for json_item in json_obj:
    print_item = False
    for pair in whitelist_pairs:
        if pair in json_item.items():
            print_item = True
            break
    if print_item:
        # print(json.dumps(json_item))
        keep_json_item_list.append(json_item)

print(json.dumps(keep_json_item_list, indent=2))
