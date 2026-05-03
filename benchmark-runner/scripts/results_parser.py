#! /usr/bin/python3

import click
import re
import typing
import os
from dotwiz import DotWiz, set_default_for_missing_keys
import csv
import yaml
import sys

with open(os.path.join(os.path.dirname(__file__), "../config/results_parser_config.yml")) as conf_file:
    CONFIG = yaml.load(conf_file, Loader=yaml.Loader)

NUMBER_REGEX = re.compile(r"^[\d\. xA-F]+$")
def insert_into_nested_dict(dictionary, keys: typing.List[str], value: str, desc: str):
    current_level = dictionary
    for key in keys:
        if key == '':
            key = 'blank'
        if key not in current_level:
            current_level[key] = dict()
        current_level = current_level[key]
        
    #value is string
    if NUMBER_REGEX.match(value) is None:
        current_level["value"] = value
        return
    
    #value is number
    try:
        current_level["value"] = int(value)
    except ValueError:
        try:
            current_level["value"] = int(value,16)
        except ValueError:
            try:
                current_level["value"] = float(value)
            except ValueError:
                current_level["value"] = value
    current_level["desc"] = desc

GEM5_LINE_REGEX = re.compile(r"([\w.:-]+)\b +([\d\.%]+|nan|\d+(?: +[\d\.%]+){2}|[a-zA-Z_\-\.\+0-9]+) +# ([\w \(\)/.,+-]+)")
def parse_gem5_stats(infile_name) -> DotWiz:
    with open(infile_name, "r") as infile:
        stat_lines = GEM5_LINE_REGEX.finditer(infile.read())
    stats = dict()
    for line in stat_lines:
        keys = line[1].split('.')
        value = line[2]
        desc = line[3]
        insert_into_nested_dict(stats, keys, value, desc)
    return DotWiz(stats)

def condense_gem5_stats(stats_dict: DotWiz, output_stats = CONFIG["output_stats"]) -> typing.List[int]:
    print(stats_dict.keys())
    out = [eval(f"stats_dict.{stat}")['value'] for stat in output_stats]
    return out

def write_csv(outfile, stats_dicts: typing.List[DotWiz]):
    filewriter = csv.writer(outfile)
    filewriter.writerow(CONFIG["output_stats"])
    filewriter.writerows([condense_gem5_stats(d) for d in stats_dicts])

@click.command()
@click.option("-o", default="-", type=click.File("w"))
@click.argument("stats-files", type=click.Path(exists=True), nargs=-1)
def main(o, stats_files):
    set_default_for_missing_keys({"value": "0.0"})
    gem5_files_to_read = [file for file in stats_files if os.stat(file).st_size > 0] # filter dummy files
    stats_dicts = [parse_gem5_stats(f) for f in gem5_files_to_read]
    write_csv(o, stats_dicts)
    return 0

if __name__ == '__main__':
    if 'snakemake' in locals() or 'snakemake' in globals():
        from snakemake.script import Snakemake
        # snakemake invocation
        args = (["-o", snakemake.output[0]] + list(snakemake.input))
        with open(snakemake.log[0], "w") as f:
            sys.stderr = sys.stdout = f
            main(args)
    else:
        # cli invocation
        main()
