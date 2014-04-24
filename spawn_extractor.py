import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file_name')
    parser.add_argument('-o', '--output', 'output_file_name', default=None)
    args = parser.parse_args()

    if parser.output_file_name is None:
        parser.output_file_name = parser.input_file_name.strip('.vmf') + '.spawns'

    angles = []
    locations = []
    with open(args.input_file_name) as f:
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


    f = open(args.output_file_name, 'w')
    f.write('\"SC_csgo1v1\"\n')
    f.write('{\n')

    for i in range(len(locations)):
        f.write("\t\"{0}\"      {1}\n".format(i, locations[i]))

    f.write('}\n')
    f.close()


if __name__ == '__main__':
    main()
