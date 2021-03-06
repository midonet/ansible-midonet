#!/usr/bin/env bash

# Copyright 2015 Midokura SARL
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script creates the fake uplink assuming that midonet is running
# correctly.  It takes the IP address CIDR as its argument which gets
# routed into the MidoNet provider router.  CIDR is defaulted to
# 172.24.4.0/24 with the gateway 172.24.4.1, but you can override by:
#
#      ./create_fake_uplink_l2.sh <network_id> 172.24.4.0/24 172.24.4.1
# or
#      CIDR=172.24.4.0/24 GATEWAY_IP=172.24.4.1 NETWORK_ID=<network_id> \
#           ./create_fake_uplink.sh
#


# Save trace setting
XTRACE=$(set +o | grep xtrace)
set +o xtrace

# Control Functions
# -----------------

# Prints line number and "message" in warning format
# warn $LINENO "message"
function warn {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[WARNING] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $xtrace
    return $exitcode
}

# Prints backtrace info
# filename:lineno:function
# backtrace level
function backtrace {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
        deep=$((deep - 1))
    done
}

# Prints line number and "message" in error format
# err $LINENO "message"
function err {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $xtrace
    return $exitcode
}

# Prints line number and "message" then exits
# die $LINENO "message"
function die {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*"
    # Give buffers a second to flush
    sleep 1
    exit $exitcode
}

# Checks an environment variable is not set or has length 0 OR if the
# exit code is non-zero and prints "message" and exits
# NOTE: env-var is the variable name without a '$'
# die_if_not_set $LINENO env-var "message"
function die_if_not_set {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        die $line "$*"
    fi
    $xtrace
}

# Test if the named environment variable is set and not zero length
# is_set env-var
function is_set {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}
# ---------------------

function usage() {
    echo "Usage: $0 <NETWORK_ID> <CIDR> <GATEWAY_IP>]" 1>&2;
    exit 1;
}

if [[ -n "$1" ]]; then
    NETWORK_ID=$1
fi

if [[ -n "$2" ]]; then
    CIDR=$2
else
    CIDR=${CIDR:-172.24.4.0/24}
fi

if [[ -n "$3" ]]; then
    GATEWAY_IP=$3
else
    GATEWAY_IP=${GATEWAY_IP:-172.24.4.1}
fi

if [ -z "${NETWORK_ID}" ] || [ -z "${CIDR}" ] || [ -z "${GATEWAY_IP}" ]; then
    usage
fi

echo "NETWORK_ID = $NETWORK_ID"
echo "CIDR = $CIDR"
echo "GATEWAY_IP = $GATEWAY_IP"

OLD_IFS=$IFS
IFS='/'; read -ra CIDR_SPLIT <<< "$CIDR"
NET_LEN=${CIDR_SPLIT[1]}
IFS=$OLD_IFS

# Save the top directory and source the functions and midorc
#TOP_DIR=$(cd $(dirname "$0") && pwd)
#source $TOP_DIR/midorc
#source $TOP_DIR/functions

set -e
set -x

# Get the host id of the devstack machine
HOST_ID=$(midonet-cli -e host list | awk '{ print $2 }')
die_if_not_set $LINENO HOST_ID "FAILED to obtain host id"
echo "Host: ${HOST_ID}"

# Check if the default tunnel zone exists
TZ_NAME='DEFAULT'
TZ_ID=$(midonet-cli -e list tunnel-zone name $TZ_NAME | awk '{ print $2 }')
if [[ -z "$TZ_ID" ]]; then
    TZ_ID=$(midonet-cli -e create tunnel-zone name $TZ_NAME type gre)
fi
echo "Tunnel Zone: ${TZ_ID}"

# Check if the host is a member of the tunnel zone
TZ_MEMBER=$(midonet-cli -e tunnel-zone $TZ_ID list member host $HOST_ID \
    address $GATEWAY_IP)
if [[ -z "$TZ_MEMBER" ]]; then
    TZ_MEMBER=$(midonet-cli -e tunnel-zone $TZ_ID add member host $HOST_ID \
        address $GATEWAY_IP)
fi
echo "Tunnel Zone Member: ${TZ_MEMBER}"

set +e
ip link list dev veth0
if [ $? != 0 ]; then
    # Create the veth interfaces
    sudo ip link add type veth
    sudo ip link set dev veth0 up
    sudo ip link set dev veth1 up
fi
set -e

# Check if we need to bind - we assume that if 'veth1' is bound, then it must
# exist, and so does veth0
BINDING=$(midonet-cli -e host $HOST_ID list binding interface veth1)
if [[ -z "$BINDING" ]]; then
    PORT_ID=$(midonet-cli -e bridge $NETWORK_ID add port)
    echo "Port: ${PORT_ID}"

    BINDING=$(midonet-cli -e host $HOST_ID add binding \
        port bridge $NETWORK_ID port $PORT_ID interface veth1)
fi
echo "Binding: ${BINDING}"

# Add the gateway address to the other veth
if ! ip addr | grep veth0 | grep $GATEWAY_IP; then
    sudo ip addr add $GATEWAY_IP/$NET_LEN dev veth0
fi

echo "Successfully created fake uplink"
