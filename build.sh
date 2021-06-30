#!/bin/bash

# This is a Building script for radiolab_docker
# Set colors
normal="\033[0m"
error="\033[41;33m"
warning="\033[43;31m"
proceed="\033[42;30m"
hint="\033[4;36m"
ERROR="${error}ERROR${normal}"
WARNING="${warning}WARNING${normal}"
PROCEED="${proceed}PROCEEDING${normal}"

# Usage
Usage () {
echo ""
echo "Build the basic Dockerfile and docker-docker-compose.yml,"
echo "then build the Docker image from the begining."
echo ""
echo "Usage: ./build.sh [options]"
echo "-r, --runtime        Specify the RUNTIME, either "normal" or "nvidia". (default: normal)"
echo "-c, --make-compose   Flag to make the docker-compose.yml file only, no argument is needed."
echo "                     No Docker image will be built."
echo "                     For making or upating docker-compose.yml."
echo "                     e.g. you have pulled the image from somewhere else,"
echo "                         or you already have the image built, and don't want to re-build the image."
echo "                     Note, the pre-built image should tag with "radiolab_docker:latest"."
echo "                       You can use the following command:"
echo "                         "docker tag \<pre-built image\> radiolab_docker:latest""
echo "-s, --ss-libev       Use ss-libev through proxychains-ng."
echo "                     T for TRUE, and F for FALSE. (default: T)"
echo "                     Note, ss config file should be copied to the build/content folder and"
echo "                       rename to shadowsocks.json"
echo "                     Also Note, only simple-obfs plugin is supported"
echo "-h, --help           Show this message."
echo ""
echo "Examples:"
echo "./build.sh -r nvidia       build the Docker image using nvidia runtime."
echo "./build.sh -r nvidia -c    make the docker-compose.yml file with nvidia runtime only,"
echo "                           but won't build the Docker image."
echo "./build.sh -r normal       build the Docker image with normal runtime."
echo "or ./build.sh"
echo "./build.sh -c              make the docker-compose.yml file with normal runtime only,"
echo "                           but won't build the Docker image."
echo ""
}

# CN_procy_control
cn_proxy() {
    file=$1
    active=$2

    if [[ -z ${active} ]]; then
        active=0
    fi

    line_edit=( $( \
        awk -v line_begin="`sed -n -e "/^# CN_SP+/=" ${file} | sed -e "s/\(.\+\)/\1 + 1/g" | bc`" \
            -v line_end="`sed -n -e "/^# CN_SP-/=" ${file} | sed -e "s/\(.\+\)/\1 - 1/g" | bc`" \
            'BEGIN {
                split(line_begin, begin, " ");
                split(line_end, end, " ");
                for (i in end) {print begin[i]","end[i]}}' ))

    for lines in ${line_edit[@]};do
        sed -i "${lines}{s/^\#\+//g}" ${file}
    done

        if [[ ${active} -eq 0 ]]; then
            for lines in ${line_edit[@]};do
                sed -i "${lines}{s/^\(.\+\)/#\1/g}" ${file}
            done
        fi
}

# Read arguments
for arg in "$@"; do
  shift
  case "$arg" in
    "--runtime")      set -- "$@" "-p" ;;
    "--make-compose") set -- "$@" "-c" ;;
    "--ss-libev")     set -- "$@" "-s" ;;
    "--help")         set -- "$@" "-h" ;;
    *)                set -- "$@" "$arg"
  esac
done

# Get runtime option
while getopts "r:s:ch" opt
do
    case ${opt} in
    r)
        RUNTIME=${OPTARG}
        ;;
    c)
        COMPOSE="Y"
        ;;
    s)
        CNOPT=${OPTARG}
        ;;
    h)
        Usage
        exit 1
        ;;
    \?)
        echo -e "${ERROR}: Invalid option."
        Usage
        exit 1
        ;;
    esac
done

if [[ -n ${CNOPT} ]]; then
    case ${CNOPT} in
        [T])
        CNSWITCH=1
        ;;
        [F])
        CNSWITCH=0
        ;;
        *)
        echo -e "${ERROR}: Invalid option, only ${hint}T${normal} or ${hint}F${normal} can be accepted by the ${hint}-s${normal} flag."
        Usage
        exit 1
        ;;
    esac
fi

# Setting a basic docker image
if [[ -z ${RUNTIME} ]]; then
    echo -e "${WARNING}: no ${hint}-r${normal} (runtime) option was supplied, so automatically setting to \"${hint}normal${normal}\" runtime."
    RUNTIME="normal"
fi
echo -e "${PROCEED}: Generating ${hint}docker-compose.yml${normal}"
echo '# docker-compose.yml that uses nvidia runtime
version: "2.3"
services:
    radiolab_flow:
        image: radiolab:latest
        runtime: nvidia
        user: $CURRENT_UID
        working_dir: /DATA
        container_name: radiolab_docker
        stdin_open: true
        environment:
            - NVIDIA_VISIBLE_DEVICES=all
            - DISPLAY=$DISPLAY
            - USER=$USER
        network_mode: "host"
        volumes:
            - $HOME:$HOME
            - $DATA:/DATA
            - $FS_LICENSE:/opt/freesurfer/license.txt
            - /tmp/.X11-unix:/tmp/.X11-unix:rw
            - /etc/group:/etc/group:ro
            - /etc/passwd:/etc/passwd:ro
            - /etc/shadow:/etc/shadow:ro
        tty: true' > docker-compose.yml
if [[ ${RUNTIME} = "nvidia" ]]; then
    if [[ -z ${COMPOSE} ]]; then
        mkdir -p build/base
        touch build/base/Dockerfile
        echo -e "${PROCEED}: Generating base ${hint}Dockerfile${normal}"
        echo -e "${PROCEED}: Building base image from \"${hint}nvidia/cudagl:9.1-runtime-ubuntu16.04${normal} with \"${hint}nvidia runtime${normal}\" support"
echo '# nvidia/cudagl:11.3.1-runtime-ubuntu20.04
FROM nvidia/cudagl:11.3.1-runtime-ubuntu20.04
# nvidia-container-runtime
ARG DEBIAN_FRONTEND=noninteractive
ENV NV_RUNTIME=TRUE \
    BASE="nvidia/cudagl:11.3.1-runtime-ubuntu20.04" \
    NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all} \
    NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics
RUN sed -i "s/archive.ubuntu.com/mirrors.ustc.edu.cn/g" /etc/apt/sources.list \
    && echo "deb https://mirrors.aliyun.com/nvidia-cuda/ubuntu1604/x86_64/ ./" > /etc/apt/sources.list.d/cuda.list \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           qt5-default \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*' > build/base/Dockerfile
    fi
elif [[ ${RUNTIME} = "normal" ]]; then
    if [[ -z ${COMPOSE} ]]; then
        mkdir -p build/base
        touch build/base/Dockerfile
        echo -e "${PROCEED}: Generating base ${hint}Dockerfile${normal}"
        echo -e "${PROCEED}: Building base image from \"${hint}ubuntu:16.04${normal}\""
echo '#ubuntu:20.04
FROM ubuntu:20.04
# mesa runtime
ARG DEBIAN_FRONTEND=noninteractive
ENV NV_RUNTIME=FALSE \
    BASE="ubuntu:20.04"
RUN sed -i "s/archive.ubuntu.com/mirrors.ustc.edu.cn/g" /etc/apt/sources.list \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           qt5-default \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*' > build/base/Dockerfile
    fi
    echo -e "${PROCEED}: Fixing ${hint}docker-compose.yml${normal} with ${hint}normal${normal} runtime configuration."
    sed  -i -e "/\s\+runtime: nvidia/{s/#//g;s/\(\s\+runtime: nvidia\)/#\1/g}" docker-compose.yml
    sed  -i -e "/\s\+-\sNVIDIA_VISIBLE_DEVICES.\+/{s/#//g;s/\(\s\+-\sNVIDIA_VISIBLE_DEVICES.\+\)/#\1/g}" docker-compose.yml
else
    echo -e "${ERROR}: ${hint}-r${normal} (RUNTIME) option can only be either \"${hint}normal${normal}\" or \"${hint}nvidia${normal}\""
    Usage
    exit 1
fi

if [[ -z ${CNSWITCH} ]]; then
    CNSWITCH=1
fi

if [[ -z ${COMPOSE} ]]; then
    ## Copy default Dockerfile
    cp build/Dockerfile_OG build/Dockerfile
    ## CN_SP
    cn_proxy build/base/Dockerfile ${CNSWITCH}
    cn_proxy build/Dockerfile ${CNSWITCH}
    ## Build base image
    docker build -t radiolab_base:latest build/base
    echo -e "${PROCEED}: Base image build complete"

    # Build Docker image with proper runtime
    echo -e "${PROCEED}: Build \"${hint}radiolab${normal}\" image from base"
    docker build -t radiolab:latest build --build-arg SYS_BUILD_DATE=UTC-$(date -u '+%Y-%m-%d')
fi
