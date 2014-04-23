import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file_name')
    parser.add_argument('output_file_name')
    args = parser.parse_args()

    # input_file_name = "/home/splewis/Dropbox/Public/test.vmf"
    # output_file_name = "/home/splewis/Dropbox/Public/test_output.spawns"

    angles = []
    locations = []
    with open(args.input_file_name) as f:
        content = f.readlines()
        n = 0
        for line in content:
            n += 1
            line = line.rstrip()
            if line == "entity":
                angle = content[n+3][10:].rstrip()
                location = content[n+5][10:].rstrip()
                angles.append(angle)
                locations.append(location)


    f = open(args.output_file_name, 'w')
    f.write('\"SC_csgo1v1\"\n')
    f.write('{\n')

    i = 0
    for location in locations:
        f.write("\t\"{0}\"      {1}\n".format(i, location))
        i += 1

    f.write('}\n')
    f.close()


if __name__ == '__main__':
    main()
