#!/usr/bin/env python3
#
# Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: Apache-2.0
#

import argparse
import re

import odb


# ----------------------------------------------------------------------------
# Pin sorting from OpenLANE
# ----------------------------------------------------------------------------

# HUMAN SORTING: https://stackoverflow.com/questions/5967500/how-to-correctly-sort-a-string-with-a-number-inside
def atof(text):
	try:
		retval = float(text)
	except ValueError:
		retval = text
	return retval

def natural_keys(enum):
	text = enum[0]
	text = re.sub("(\[|\]|\.|\$)", "", text)
	'''
	alist.sort(key=natural_keys) sorts in human order
	http://nedbatchelder.com/blog/200712/human_sorting.html
	(see toothy's implementation in the comments)
	float regex comes from https://stackoverflow.com/a/12643073/190597
	'''
	return [atof(c) for c in re.split(r'[+-]?([0-9]+(?:[.][0-9]*)?|[.][0-9]+)', text)]

def bus_keys(enum):
	text = enum[0]
	m = re.match("^.*\[(\d+)\]$", text)
	if not m:
		return -1
	else:
		return int(m.group(1))


def pin_config_load(filename):
	bus_sort = False
	pin_placement_cfg = {"#N": [], "#E": [], "#S": [], "#W": []}
	cur_side = None

	with open(filename, 'r') as config_file:
		for line in config_file:
			line = line.split()
			if len(line) == 0:
				continue

			if len(line) > 1:
				print("[!] Only one entry allowed per line.")
				return None

			token = line[0]

			if cur_side is not None and token[0] != "#":
				pin_placement_cfg[cur_side].append(token)

			elif token not in ["#N", "#E", "#S", "#W", "#NR", "#ER", "#SR", "#WR", "#BUS_SORT"]:
				print("[!] Valid directives are #N, #E, #S, or #W. Append R for reversing the default order.",
					"Use #BUS_SORT to group 'bus bits' by index.",
					"Please make sure you have set a valid side first before listing pins")
				return None

			elif token == "#BUS_SORT":
				bus_sort = True

			else:
				if len(token) == 3:
					token = token[0:2]
					reverse_arr.append(token)
				cur_side = token

	return pin_placement_cfg, bus_sort


def pin_config_apply(block, pin_cfg, bus_sort=False):
	# Collect all block terminals
	bterms = block.getBTerms()
	bterms_enum = []
	for bterm in bterms:
		pin_name = bterm.getConstName()
		bterms_enum.append((pin_name, bterm))

	# Sort them "humanly"
	bterms_enum.sort(key=natural_keys)
	if bus_sort:
		bterms_enum.sort(key=bus_keys)
	bterms = [ bterm[1] for bterm in bterms_enum ]

	# Place according to config
	pin_placement = {"#N": [], "#E": [], "#S": [], "#W": []}
	bterm_regex_map = {}

	for side in pin_cfg:
		for regex in pin_cfg[side]:  # going through them in order
			regex += "$"  # anchor
			for bterm in bterms:
				# if a pin name matches multiple regexes, their order will be
				# arbitrary. More refinement requires more strict regexes (or just
				# the exact pin name).
				pin_name = bterm.getConstName()

				if re.match(regex, pin_name) is not None:
					if bterm in bterm_regex_map:
						print("Warning: Multiple regexes matched", pin_name,
							". Those are", bterm_regex_map[bterm], "and", regex)
						print("Only the first one is taken into consideration.")
						continue

					bterm_regex_map[bterm] = regex
					pin_placement[side].append(bterm)  # to maintain the order

	#for side, btl in pin_placement.items():
	#	print(side)
	#	print([bt.getConstName() for bt in btl])

	return pin_placement


# ----------------------------------------------------------------------------
# Buffer/Diode placement
# ----------------------------------------------------------------------------

CELL_DIODE  = 'sky130_fd_sc_hd__diode_2'
CELL_BUFFER = 'sky130_fd_sc_hd__buf_8'


def place_buf_diode(block, pin_sides):
	# Get all rows
	rows = sorted(block_design.getRows(), key=lambda x: x.getOrigin()[1])

	# Scan sides
	for side, bt_lst in pin_sides.items():
		# Only do 'W' / 'E'
		if side not in ['#E', '#W']:
			continue

		# Find center rows and place in it
		s = (len(rows) - len(bt_lst)) // 2

		for row, bt in zip(rows[s:], bt_lst):
			# Init
			to_place = []

			# Find Diode and Buffer
			inst_diode  = None
			inst_buffer = None
			io_type     = bt.getIoType()

			if io_type == 'INPUT':
				# Both buffer and diode connected to pin
				for it in bt.getNet().getITerms():
					inst = it.getInst()
					cn = inst.getMaster().getConstName()
					if cn == CELL_DIODE:
						inst_diode = inst
					elif cn == CELL_BUFFER:
						inst_buffer = inst

				# Order
				if inst_diode:
					to_place.append(inst_diode)
				if inst_buffer:
					to_place.append(inst_buffer)

			elif io_type == 'OUTPUT':
				# Find buffer first
				for it in bt.getNet().getITerms():
					inst = it.getInst()
					cn = inst.getMaster().getConstName()
					if cn == CELL_BUFFER:
						inst_buffer = inst

				# Find diode on the buffers input
				if inst_buffer is None:
					import IPython
					IPython.embed()

				for it in inst_buffer.findITerm('A').getNet().getITerms():
					inst = it.getInst()
					cn = inst.getMaster().getConstName()
					if cn == CELL_DIODE:
						inst_diode = inst

				# Order
				if inst_buffer:
					to_place.append(inst_buffer)
				if inst_diode:
					to_place.append(inst_diode)

			# Place them
			sc = row.getSiteCount()
			sw = row.getSite().getWidth()

			if side == '#W':
				pos = 20 * sw
				for inst in to_place:
					inst.setOrient(row.getOrient())
					inst.setLocation(pos, row.getOrigin()[1])
					inst.setPlacementStatus('FIRM')
					pos += inst.getMaster().getWidth() + 2 * sw

			elif side == '#E':
				pos = (sc - 20) * sw
				for inst in to_place:
					pos -= inst.getMaster().getWidth() + 2 * sw
					inst.setOrient(row.getOrient())
					inst.setLocation(pos, row.getOrigin()[1])
					inst.setPlacementStatus('FIRM')


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# Arguments
parser = argparse.ArgumentParser(
		description='Cleanup XXX')

parser.add_argument('--lef', '-l',
		nargs='+',
		type=str,
		default=None,
		required=True,
		help='Input LEF file(s)')

parser.add_argument('--input-def', '-id', required=True,
		help='DEF view of the design that needs to have its instances placed')

parser.add_argument('--output-def', '-o', required=True,
		help='Output placed DEF file')

parser.add_argument('--pin-config', '-p', required=True,
		help='IO configuration file')


args = parser.parse_args()
input_lef_file_names = args.lef
input_def_file_name = args.input_def
output_def_file_name = args.output_def
pin_config_file_name = args.pin_config

# Load
db_design = odb.dbDatabase.create()

for lef in input_lef_file_names:
	odb.read_lef(db_design, lef)
odb.read_def(db_design, input_def_file_name)

chip_design = db_design.getChip()
block_design = chip_design.getBlock()
top_design_name = block_design.getName()
print("Design name:", top_design_name)


# Process
pin_cfg, bus_sort = pin_config_load(pin_config_file_name)
pin_sides = pin_config_apply(block_design, pin_cfg, bus_sort)
place_buf_diode(block_design, pin_sides)


# Write result
odb.write_def(block_design, output_def_file_name)
