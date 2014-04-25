#! /usr/bin/env python

import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('-o', '--output', default=None)
    args = parser.parse_args()

    if args.output is None:
        args.output = args.input.strip('.vmf') + '.spawns'

    angles = []
    locations = []
    with open(args.input) as f:
        content = f.readlines()
        n = 0
        for line in content:
            n += 1
            line = line.rstrip()
            if line == "entity":
                name = content[n+2][14:-3]
                if name == 'info_player_terrorist' or name == 'info_player_counterterrorist':
                    angle = content[n+3][10:].rstrip()
                    location = content[n+5][10:].rstrip()
                    angles.append(angle)
                    locations.append(location)


    f = open(args.output, 'w')
    f.write('\"multi1v1\"\n')
    f.write('{\n')

    for i in range(len(locations)):
        f.write("\t\"{0}\"      {1}\n".format(i, locations[i]))

    f.write('}\n')
    f.close()


if __name__ == '__main__':
    main()
