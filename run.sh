#!/bin/bash

# DATASETS='citeseer cora epinions familial-er imdb-er jester jester-full lastfm yelp'
DATASETS='citeseer cora epinions familial-er jester jester-full lastfm yelp'

function main() {
    trap exit SIGINT

    local datasetPaths=''
    for dataset in $DATASETS; do
        datasetPaths="${datasetPaths} psl-examples/${dataset}"
    done

    ./scripts/run_memory_experiments.sh $datasetPaths
}

main "$@"
