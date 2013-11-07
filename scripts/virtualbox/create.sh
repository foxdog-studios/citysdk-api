#!/bin/bash

# Copyright 2013 Foxdog Studios
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

set -o errexit
set -o nounset


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

usage() {
    echo 'Usage: create.sh [ADAPTER]'
    exit 1
}

if [[ "${#}" != 1 ]]; then
    usage
fi


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

manage() {
    VBoxManage "${1}" "${name}" "${@:2}"
}


vmdir() {
    dirname "$(manage showvminfo --machinereadable                            \
        | grep '^CfgFile'                                                     \
        | sed 's/.*"\(.*\)"/\1/g'
    )"
}


# =============================================================================
# = Configuration                                                             =
# =============================================================================

name=CitySDK

adpater=${1}
cpus=4
hd_name=${name}-disk1.vmdk
hd_size=40000 # MB (40 GB)
memory=1000 # MB (1 GB)
ostype=Ubuntu_64
storagectl_name='SATA'


# =============================================================================
# = Create VirtualBox                                                         =
# =============================================================================

VBoxManage createvm                                                           \
    --name "${name}"                                                          \
    --register

manage modifyvm                                                               \
    --bridgeadapter1 "${adpater}"                                             \
    --cpus "${cpus}"                                                          \
    --ioapic on                                                               \
    --memory "${memory}"                                                      \
    --nic1 bridged                                                            \
    --ostype "${ostype}"                                                      \
    --rtcuseutc on

manage storagectl                                                             \
    --add sata                                                                \
    --name "${storagectl_name}"

hd_path=$(vmdir)/${hd_name}

VBoxManage createhd                                                           \
    --filename "${hd_path}"                                                   \
    --size "${hd_size}"

manage storageattach                                                          \
    --device 0                                                                \
    --medium "${hd_path}"                                                     \
    --port 0                                                                  \
    --storagectl "${storagectl_name}"                                         \
    --type hdd                                                                \

