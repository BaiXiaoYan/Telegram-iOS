#!/bin/sh

set -e
set -x

BUILDBOX_DIR="buildbox"

mkdir -p "$BUILDBOX_DIR/transient-data"

BUILD_CONFIGURATION="$1"

if [ "$BUILD_CONFIGURATION" == "hockeyapp" ]; then
	CODESIGNING_SUBPATH="transient-data/codesigning"
elif [ "$BUILD_CONFIGURATION" == "appstore" ]; then
	CODESIGNING_SUBPATH="transient-data/codesigning"
elif [ "$BUILD_CONFIGURATION" == "verify" ]; then
	CODESIGNING_SUBPATH="fake-codesigning"
else
	echo "Unknown configuration $1"
	exit 1
fi

if [ ! -d "$BUILDBOX_DIR/$CODESIGNING_SUBPATH" ]; then
	echo "$BUILDBOX_DIR/$CODESIGNING_SUBPATH does not exist"
	exit 1
fi

tar czf "$BUILDBOX_DIR/transient-data/source.tar.gz" --exclude "$BUILDBOX_DIR" .

VM_BASE_NAME="macos10_14_3_Xcode10_1"

SNAPSHOT_ID=$(prlctl snapshot-list "$VM_BASE_NAME" | grep -Eo '\{(\d|[a-f]|-)*\}' | tr '\n' '\0')

if [ -z "$SNAPSHOT_ID" ]; then
	echo "$VM_BASE_NAME is required to have one snapshot"
	exit 1
fi

VM_NAME="$VM_BASE_NAME-$(openssl rand -hex 10)"

prlctl clone "$VM_BASE_NAME" --name "$VM_NAME"
prlctl snapshot-switch "$VM_NAME" -i "$SNAPSHOT_ID"

VM_IP=$(prlctl exec "$VM_NAME" "ifconfig | grep inet | grep broadcast | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | tr '\n' '\0'")

scp -pr "$BUILDBOX_DIR/$CODESIGNING_SUBPATH" telegram@"$VM_IP":codesigning_data
scp -pr "$BUILDBOX_DIR/transient-data/telegram-ios-shared" telegram@"$VM_IP":telegram-ios-shared
scp -pr "$BUILDBOX_DIR/guest-build-telegram.sh" "$BUILDBOX_DIR/transient-data/source.tar.gz" telegram@"$VM_IP":

ssh telegram@"$VM_IP" -o ServerAliveInterval=60 -t "bash -l guest-build-telegram.sh $BUILD_CONFIGURATION"

#prlctl stop "$VM_NAME" --kill
#prlctl delete "$VM_NAME"
