#!/bin/bash

set -u

OUTPUT_DIR="/tmp/g5k-check-reset"

help () {

echo """Usage:
-s SITE
-c CLUSTER
-n NODE (not yet implmented
-o OUTPUT_DIR to put the yaml file, default : $OUTPUT_DIR"""

}

while getopts "s:c:n:o:h" opt;
do
    case $opt in
        s)
            SITE=$OPTARG
            ;;
        c)
            CLUSTER=$OPTARG
            ;;
        n)
            NODE=$OPTARG
            ;;
        o)
            OUTPUT_DIR=$OPTARG
            ;;
        h)
            help
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

mkdir -p $OUTPUT_DIR

NODES=$(nodes5k -s $SITE -c $CLUSTER)
NODES_F=$(echo $NODES | nodeset -f)

CLUSH_CMD="clush -w $NODES_F"

$CLUSH_CMD "g5k-checks -c <(echo -e "testlist: \n  - all\n") -m api -e os"
$CLUSH_CMD --rcopy /tmp/*.yaml --dest $OUTPUT_DIR

cd $OUTPUT_DIR
for name in *
do
    mv $name ${name#*.yaml.}.yaml
done

sed -ri "s/^(.*)$/  \1/" $OUTPUT_DIR/*

xargs -d' ' -a <(echo $NODES) -Inode sed -i -e "1 s/^.*$/---\nnode:/" node.yaml

cd -
