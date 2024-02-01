# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

addr: "0.0.0.0:${PORT}"

# Which storage engine should be used by controller
# options: etcd, zookeeper
# default: etcd
storage_type: etcd

etcd:
  addrs:
    - "${IP}:${ETCD_CLIENT_PORT}"
  username:
  password:
  elect_path:
  tls:
    enable: false
    cert_file:
    key_file:
    ca_file:

controller:
  failover:
    gc_interval_seconds: 3600
    ping_interval_seconds: 5
    min_alive_size: 10
    max_failure_ratio: 0.6