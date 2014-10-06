#
# Cookbook Name:: openstack-cinder
# Recipe:: controller
#
# Copyright 2014, FutureSystems, Indiana University
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
#

secrets = Chef::EncryptedDataBagItem.load("openstack", "secrets")

package 'ntp'
package 'python-mysqldb'
package 'python-memcache'
package 'python-keystoneclient'
package 'cinder-api'
package 'cinder-scheduler'

services = %w{cinder-api cinder-scheduler}
services.each do |svc|
  service svc do
    supports :restart => true
    restart_command "restart #{svc} || start #{svc}"
    action :nothing
  end
end

template "/etc/cinder/cinder.conf" do
  source "cinder.conf.erb"
  mode "0640"
  owner "cinder"
  group "cinder"
  action :create
  variables(
    :admin_address => node["openstack"]["admin_address"],
    :public_address => node["openstack"]["public_address"],
    :service_password => secrets['service_password'],
    :mysql_user => secrets['mysql_user'],
    :mysql_password => secrets['mysql_password'],
    :rabbit_user => secrets['rabbit_user'],
    :rabbit_password => secrets['rabbit_password'],
    :rabbit_virtual_host => secrets['rabbit_virtual_host']
  )
  notifies :run, "execute[cinder_manage_db_sync]", :immediately
  notifies :restart, "service[cinder-api]", :immediately
  notifies :restart, "service[cinder-scheduler]", :immediately
end

execute "cinder_manage_db_sync" do
  user "cinder"
  command "cinder-manage db sync && touch /etc/cinder/.db_synced_do_not_delete"
  creates "/etc/cinder/.db_synced_do_not_delete"
  action :nothing
end
