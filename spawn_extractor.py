#!/usr/bin/env python

import argparse
import json
import os, os.path


def parse_special(filename, verbose=False):
    input_file = filename + '.txt'
    if os.path.exists(input_file):
        json_data = open(input_file)
        data = json.load(json_data)
        json_data.close()
        if verbose:
            print('\twith special commands:' + str(data))
        return data
    else:
        return {}


def create_config(filename, special_commands={}):
    angles = []
    locations = []
    with open(filename + '.vmf') as f:
        content = f.readlines()

        for n in range(len(content)):
            line = content[n].strip()
            if line == "entity":
                def fetch_field(name):
                    for j in range(n + 1, len(content)):
                        entity_data = content[j].strip().replace('"', '').split(' ')
                        if entity_data[0] == name:
                            return ' '.join(entity_data[1:])
                    return None

                name = fetch_field('classname')
                if name == 'info_player_terrorist':
                    locations.append(fetch_field('origin'))
                    # print special_commands
                    try:
                        angles.append(special_commands['player1angles'])
                    except:
                        angles.append(fetch_field('angles'))

                if name == 'info_player_counterterrorist':
                    locations.append(fetch_field('origin'))
                    try:
                        angles.append(special_commands['player2angles'])
                    except KeyError:
                        angles.append(fetch_field('angles'))



    map_name = filename[4:]  # removes the 'maps' in the file path
    dir_name = os.path.dirname('csgo/addons/sourcemod/configs/multi1v1' + map_name)
    if not os.path.exists(dir_name):
        os.makedirs(dir_name)
    outfile_name = 'csgo/addons/sourcemod/configs/multi1v1' + filename[4:] + '.cfg'  # remove the maps with the [4"]
    f = open(outfile_name, 'w')

    def write(text, num_tabs=0):
        tabs = ''.join(['\t'] * num_tabs)
        f.write(tabs + text + '\n')

    write('\"multi1v1_arenas\"')
    write('{')

    for i in range(len(locations)):
        origin = locations[i]
        angle = angles[i]
        write('\"spawn{0}\"'.format(i+1), 1)
        write('{', 1)
        write('\"origin"\t\t\"{0}\"'.format(origin), 2)
        write('\"angle"\t\t\"{0}\"'.format(angle), 2)
        write('}', 1)

    write('}')
    f.close()


def main():
    parser = argparse.ArgumentParser(description='')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()

    for root, _, files in os.walk('maps'):
        for f in files:
            fullpath = os.path.join(root, f)
            extension = fullpath[-4:]
            if extension == '.vmf':
                if args.verbose:
                    print ('creating config for {0}'.format(fullpath))
                no_extension_name = fullpath[:-4]
                special_commands = parse_special(no_extension_name, args.verbose)
                create_config(no_extension_name, special_commands)


if __name__ == '__main__':
    main()
