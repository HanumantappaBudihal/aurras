#!/bin/bash

# To run this command
# ./deploy.sh --openwhiskApiHost <openwhiskApiHost> --openwhiskApiKey <openwhiskApiKey> --openwhiskNamespace <openwhiskNamespace>

openwhiskApiHost=${openwhiskApiHost:-https://localhost:31001}
openwhiskApiKey=${openwhiskApiKey:-23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP}
openwhiskNamespace=${openwhiskNamespace:-guest}
actionHome=${actionHome:-actions/substrate-event-processor}
WSK_CLI="wsk"
DOCKER_IMAGE="hugobyte/openwhisk-runtime-rust:v0.2"
if ! command -v $WSK_CLI &> /dev/null
then
    echo "wsk cli not found in path. Please get the cli from https://github.com/apache/openwhisk-cli/releases"
    exit
fi


ACTION="substrate-event-processor"
PACKAGE_HOME="$PWD/${actionHome}/temp/$ACTION"

while [ $# -gt 0 ]; do
    if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="${2%/}"
    fi

    shift
done

set -e

cd "$PWD/$actionHome"

if [ -e ./temp/${ACTION} ]; then
    echo "Clearing previously packed action file."
    rm -rf ./temp/${ACTION}
fi

mkdir -p ./temp/${ACTION}
echo "Creating temporary directory"
echo "$PACKAGE_HOME/main.zip"
echo "Building Source"
zip -r - Cargo.toml src | docker run -e RELEASE=true -i --rm ${DOCKER_IMAGE} -compile main > "$PACKAGE_HOME/main.zip"

cd ./temp/${ACTION}

$WSK_CLI -i --apihost "$openwhiskApiHost" action update ${ACTION} "$PACKAGE_HOME/main.zip" --docker "$DOCKER_IMAGE" \
    --auth "$openwhiskApiKey" --param event_producer_trigger "produce-event" -a provide-api-key true


$WSK_CLI -i --apihost "$openwhiskApiHost" trigger update "produce-event" --auth "$openwhiskApiKey"

$WSK_CLI -i --apihost "$openwhiskApiHost" rule update "produce-event-rule" "produce-event" "event-producer" --auth "$openwhiskApiKey"

if [ -e ./temp/${ACTION} ]; then
    echo "Clearing temporary packed action file."
    rm -rf ./temp/${ACTION}
fi