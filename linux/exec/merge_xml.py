#!/usr/bin/env python

import os
import sys
from typing import Any
from pathlib import Path
from collections import defaultdict
from xml.etree import ElementTree as ET

from typer import run


def etree_to_dict(t: ET.Element) -> dict[str, Any]:
    d: dict[str, Any] = {t.tag: {} if t.attrib else None}
    children = list(t)
    if children:
        dd = defaultdict(list)
        for dc in map(etree_to_dict, children):
            for k, v in dc.items():
                dd[k].append(v)
        d = {t.tag: {k: v[0] if len(v) == 1 else v for k, v in dd.items()}}
    if t.attrib:
        d[t.tag].update(("@" + k, v) for k, v in t.attrib.items())
    if t.text:
        text = t.text.strip()
        if children or t.attrib:
            if text:
                d[t.tag]["#text"] = text
        else:
            d[t.tag] = text
    return d


def dict_to_etree(d: dict[str, Any]) -> ET.Element:
    def _to_etree(d: dict[str, Any] | str, root: ET.Element) -> None:
        if not d:
            pass
        elif isinstance(d, str):
            root.text = d
        elif isinstance(d, dict):
            for k, v in d.items():
                assert isinstance(k, str)
                if k.startswith("#"):
                    assert k == "#text" and isinstance(v, str)
                    root.text = v
                elif k.startswith("@"):
                    assert isinstance(v, str)
                    root.set(k[1:], v)
                elif isinstance(v, list):
                    for e in v:
                        _to_etree(e, ET.SubElement(root, k))
                else:
                    _to_etree(v, ET.SubElement(root, k))
        else:
            assert d == "invalid type", (type(d), d)

    assert isinstance(d, dict) and len(d) == 1
    tag, body = next(iter(d.items()))
    node = ET.Element(tag)
    _to_etree(body, node)
    return node


def merge_etree_dicts(t_dest: dict[str, Any], t_input: dict[str, Any]) -> None:
    for in_k, in_v in t_input.items():
        if in_k not in t_dest:
            t_dest[in_k] = in_v
        else:
            dest_v = t_dest[in_k]
            if in_v == dest_v:
                pass
            elif isinstance(in_v, list):
                for el in in_v:
                    if el not in dest_v:
                        dest_v.append(el)
            else:
                merge_etree_dicts(dest_v, in_v)


def merge_xml_files(
    *in_xml_paths: Path,
) -> None:
    base_tree_dict = etree_to_dict(ET.parse(sys.argv[1]).getroot())
    for xml_fp in in_xml_paths:
        merge_etree_dicts(base_tree_dict, etree_to_dict(ET.parse(xml_fp).getroot()))

    tree = ET.ElementTree(dict_to_etree(base_tree_dict))
    ET.indent(tree, space="    ")

    with os.fdopen(sys.stdout.fileno(), "wb", closefd=False) as stdout:
        tree.write(stdout, encoding="utf-8", xml_declaration=True)
        stdout.flush()


if __name__ == "__main__":
    run(merge_xml_files)
