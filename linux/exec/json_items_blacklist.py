#!/usr/bin/env python

import json
import sys

blacklist_pairs = [
    tuple(item.strip().strip('"') for item in line.strip().rstrip(",").split(":"))
    for line in sys.stdin.readlines()
]

json_obj = json.load(open(sys.argv[1], "r"))

keep_json_item_list = []
for json_item in json_obj:
    print_item = True
    for pair in blacklist_pairs:
        if pair in json_item.items():
            print_item = False
            break
    if print_item:
        # print(json.dumps(json_item))
        keep_json_item_list.append(json_item)

print(json.dumps(keep_json_item_list, indent=2))
