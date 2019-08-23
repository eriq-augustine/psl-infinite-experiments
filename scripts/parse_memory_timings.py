#!/usr/bin/env python3

import os
import re
import sys

PSL_LOG_FILENAME = 'out.txt'
PSL_TIMING_FILENAME = 'time.txt'

KEY_ITERATION = 'Iteration'
KEY_DATASET = 'Dataset'
KEY_METHOD = 'Method'
KEY_INFERENCE_TIME = 'Inference Time'
KEY_NUM_ITERATIONS = 'Inference Iterations'
KEY_MAX_MEMORY = 'Max Memory'
KEY_MEAN_MEMORY = 'Mean Memory'
KEY_READ_OPS = 'Read Ops'
KEY_READ_BYTES = 'Read Bytes'
KEY_WRITE_OPS = 'Write Ops'
KEY_WRITE_BYTES = 'Write Bytes'

def parse_log(path):
    row = {
        KEY_INFERENCE_TIME: -1,
        KEY_NUM_ITERATIONS: -1,
        KEY_MAX_MEMORY: -1,
        KEY_MEAN_MEMORY: -1,
        KEY_READ_OPS: -1,
        KEY_READ_BYTES: -1,
        KEY_WRITE_OPS: -1,
        KEY_WRITE_BYTES: -1,
    }

    with open(path, 'r') as file:
        for line in file:
            line = line.strip()
            if (line == ''):
                continue

            match = re.search(r'^(\d+)\s+', line)
            if (match is not None):
                time = int(match.group(1))

            match = re.search(r'Atom manager initialization complete.', line)
            if (match is not None):
                inference_start = time
                continue

            match = re.search(r'Optimization completed in (\d+) iterations.', line)
            if (match is not None):
                row[KEY_NUM_ITERATIONS] = int(match.group(1))
                continue

            match = re.search(r'Inference complete. Writing results to Database.', line)
            if (match is not None):
                row[KEY_INFERENCE_TIME] = time - inference_start
                continue

            match = re.search(r'Total Memory \(bytes\) -- Min:\s*(\d+), Max:\s*(\d+), Mean:\s*(\d+), Count:\s*(\d+)', line)
            if (match is not None):
                continue

            match = re.search(r'Free Memory \(bytes\) -- Min:\s*(\d+), Max:\s*(\d+), Mean:\s*(\d+), Count:\s*(\d+)', line)
            if (match is not None):
                continue

            match = re.search(r'Used Memory \(bytes\) -- Min:\s*(\d+), Max:\s*(\d+), Mean:\s*(\d+), Count:\s*(\d+)', line)
            if (match is not None):
                row[KEY_MAX_MEMORY] = int(match.group(2))
                row[KEY_MEAN_MEMORY] = int(match.group(3))
                continue

            match = re.search(r'Max Memory \(bytes\) -- Min:\s*(\d+), Max:\s*(\d+), Mean:\s*(\d+), Count:\s*(\d+)', line)
            if (match is not None):
                continue

            match = re.search(r'IO Reads \(bytes\)     -- Min:\s*(\d+), Max:\s*(\d+), Mean:\s*(\d+), Count:\s*(\d+), Total:\s*(\d+)', line)
            if (match is not None):
                row[KEY_READ_OPS] = int(match.group(4))
                row[KEY_READ_BYTES] = int(match.group(5))
                continue

            match = re.search(r'IO Writes \(bytes\)    -- Min:\s*(\d+), Max:\s*(\d+), Mean:\s*(\d+), Count:\s*(\d+), Total:\s*(\d+)', line)
            if (match is not None):
                row[KEY_WRITE_OPS] = int(match.group(4))
                row[KEY_WRITE_BYTES] = int(match.group(5))
                continue

    return row

def parse_dir(results_dir):
    rows = []

    for iteration in os.listdir(results_dir):
        iteration_path = os.path.join(results_dir, iteration)

        for dataset in os.listdir(iteration_path):
            dataset_path = os.path.join(iteration_path, dataset)

            for method in os.listdir(dataset_path):
                method_path = os.path.join(dataset_path, method)

                log_path = os.path.join(method_path, PSL_LOG_FILENAME)
                if (not os.path.isfile(log_path)):
                    continue

                row = parse_log(log_path)

                row[KEY_ITERATION] = int(iteration)
                row[KEY_DATASET] = dataset
                row[KEY_METHOD] = method

                rows.append(row)

    return rows

def main(results_dir):
    rows = parse_dir(results_dir)

    if (len(rows) == 0):
        return

    headers = sorted(list(rows[0].keys()))
    print("\t".join(headers))

    for row in rows:
        print("\t".join([str(row[header]) for header in headers]))

def _load_args(args):
    executable = args.pop(0)
    if (len(args) != 1 or ({'h', 'help'} & {arg.lower().strip().replace('-', '') for arg in args})):
        print("USAGE: python3 %s <memory results dir>" % (executable), file = sys.stderr)
        sys.exit(1)

    path = os.path.abspath(args.pop(0))

    return path

if (__name__ == '__main__'):
    main(_load_args(sys.argv))