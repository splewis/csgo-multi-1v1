#!/usr/bin/env python

import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('-o', '--output', default=None)
    args = parser.parse_args()

    if args.output is None:
        args.output = 'out.txt'

    angles = []
    locations = []
    with open(args.input) as f:
        content = f.readlines()

        n = 0
        for line in content:
            n += 1
            line = line.strip()
            if line == "entity":
                def fetch_field(name):
                    for j in range(n + 1, len(content)):
                        entity_data = content[j].strip().replace('"', '').split(' ')
                        if entity_data[0] == name:
                            return ' '.join(entity_data[1:])
                    return None

                name = fetch_field('classname')
                if name == 'info_player_terrorist' or name == 'info_player_counterterrorist':
                    locations.append(fetch_field('origin'))
                    angles.append(fetch_field('angles'))


    f = open(args.output, 'w')
    f.write('\"SC_multi1v1\"\n')
    f.write('{\n')

    for i in range(len(locations)):
        f.write("\t\"{0}\"      \"{1}\"\n".format(i, locations[i]))

    f.write('}\n')
    f.close()


if __name__ == '__main__':
    main()
