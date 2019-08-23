#!/bin/bash

# Run experiments that show the effectiveness of page sizes on convergence, speed, and memory usage.

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_OUT_DIR="${THIS_DIR}/../results/memory"

readonly CLEAR_CACHE_SCRIPT=$(realpath "${THIS_DIR}/clear_cache.sh")
readonly BSOE_CLEAR_CACHE_SCRIPT=$(realpath "${THIS_DIR}/bsoe_clear_cache.sh")

# A directory that only exists on BSOE servers.
readonly BSOE_DIR='/soe'

readonly NUM_RUNS=10
readonly PAGE_SIZES='10 100 1000 10000 100000 1000000'

readonly STANDARD_PSL_OPTIONS='-D runtimestats.collect=true'
readonly STANDARD_SGD_OPTIONS='-D sgd.maxiterations=5000'

readonly SHUFFLE_OPTIONS='-D streamingtermstore.shufflepage=true -D readonly streamingtermstore.randomizepageaccess=true'
readonly NO_SHUFFLE_OPTIONS='-D streamingtermstore.shufflepage=false -D readonly streamingtermstore.randomizepageaccess=false'

function clearPostgresCache() {
    if [[ -d "${BSOE_DIR}" ]]; then
        "${BSOE_CLEAR_CACHE_SCRIPT}"
    else
        sudo "${CLEAR_CACHE_SCRIPT}"
    fi
}

function run() {
    local cliDir=$1
    local outDir=$2
    local extraOptions=$3

    mkdir -p "${outDir}"

    local outPath="${outDir}/out.txt"
    local errPath="${outDir}/out.err"
    local timePath="${outDir}/time.txt"

    if [[ -e "${outPath}" ]]; then
        echo "Output file already exists, skipping: ${outPath}"
        return 0
    fi

    clearPostgresCache

    pushd . > /dev/null
        cd "${cliDir}"
        /usr/bin/time -v --output="${timePath}" ./run.sh ${extraOptions} > "${outPath}" 2> "${errPath}"
    popd > /dev/null
}

function run_example() {
    local exampleDir=$1
    local iteration=$2

    local exampleName=`basename "${exampleDir}"`
    local cliDir="$exampleDir/cli"

    local outDir=''
    local options=''

    local baseOutDir="${BASE_OUT_DIR}/${iteration}/${exampleName}"

    # Run a standard ADMM run.
    echo "Running ${exampleName} -- base."
    outDir="${baseOutDir}/admm"

    options="${STANDARD_PSL_OPTIONS}"

    run "${cliDir}" "${outDir}" "${options}"

    # Run a SGD run.
    echo "Running ${exampleName} -- Memory SGD."
    outDir="${baseOutDir}/sgd_memory"

    options="${STANDARD_PSL_OPTIONS}"
    options="${options} -D inference.reasoner=SGDReasoner -D inference.termstore=SGDMemoryTermStore -D inference.termgenerator=SGDTermGenerator"
    options="${options} ${STANDARD_SGD_OPTIONS}"

    run "${cliDir}" "${outDir}" "${options}"

    # Now run SGD with different page sizes.
    for pageSize in ${PAGE_SIZES}; do
        # Shuffle
        echo "Running ${exampleName} -- Streaming SGD (${pageSize}, shuffle)."
        outDir="${baseOutDir}/sgd_streaming_$(printf '%08d' ${pageSize})"

        options="${STANDARD_PSL_OPTIONS}"
        options="${options} --infer SGDStreamingInference"
        options="${options} -D streamingtermstore.warnunsupportedrules=false"
        options="${options} -D streamingtermstore.pagesize=${pageSize}"
        options="${options} ${SHUFFLE_OPTIONS}"
        options="${options} ${STANDARD_SGD_OPTIONS}"

        run "${cliDir}" "${outDir}" "${options}"

        # Shuffle
        echo "Running ${exampleName} -- Streaming SGD (${pageSize}, no shuffle)."
        outDir="${baseOutDir}/sgd_streaming_$(printf '%08d' ${pageSize})_noshuffle"

        options="${STANDARD_PSL_OPTIONS}"
        options="${options} --infer SGDStreamingInference"
        options="${options} -D streamingtermstore.warnunsupportedrules=false"
        options="${options} -D streamingtermstore.pagesize=${pageSize}"
        options="${options} ${NO_SHUFFLE_OPTIONS}"
        options="${options} ${STANDARD_SGD_OPTIONS}"

        run "${cliDir}" "${outDir}" "${options}"
    done
}

function main() {
    if [[ $# -eq 0 ]]; then
        echo "USAGE: $0 <example dir> ..."
        exit 1
    fi

    trap exit SIGINT

    for i in `seq -w 1 ${NUM_RUNS}`; do
        for exampleDir in "$@"; do
            run_example "${exampleDir}" "${i}"
        done
    done
}

main "$@"
