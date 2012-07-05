#
# Cookbook Name:: storm
# Recipe:: default
#
# Copyright 2012, Webtrends
#
# All rights reserved - Do Not Redistribute
#


include_recipe "runit"
include_recipe "java"

# install dependency packages
%w{unzip python zeromq jzmq}.each do |pkg|
  package pkg do
    action :install
    options "--force-yes"
  end
end

# search
storm_nimbus = search(:node, "role:storm_nimbus AND role:#{node['storm']['cluster_role']} AND chef_environment:#{node.chef_environment}").first

# search for zookeeper servers
zookeeper_quorum = Array.new
search(:node, "role:zookeeper AND chef_environment:#{node.chef_environment}").each do |n|
	zookeeper_quorum << n[:fqdn]
end

# fall back to attribs if search doesn't come up with any zookeeper roles
if zookeeper_quorum.count == 0
	node['zookeeper']['quorum'].each do |i|
		zookeeper_quorum << i
	end
end

install_dir = "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"

# setup storm group
group "storm" do
end

# setup storm user
user "storm" do
  comment "Storm user"
  gid "storm"
  shell "/bin/bash"
  home "/home/storm"
  supports :manage_home => true
end

# setup directories
%w{install_dir local_dir log_dir}.each do |name|
  directory node['storm'][name] do
    owner "storm"
    group "storm"
    action :create
    recursive true
  end
end

# download storm
remote_file "#{Chef::Config[:file_cache_path]}/storm-#{node[:storm][:version]}.tar.gz" do
  source "#{node[:storm][:download_url]}/storm-#{node[:storm][:version]}.tar.gz"
  owner  "storm"
  group  "storm"
  mode   00744
  not_if "test -f #{Chef::Config[:file_cache_path]}/storm-#{node[:storm][:version]}.tar.gz"
end

# uncompress the application tarball into the install directory
execute "tar" do
  user    "storm"
  group   "storm"
  creates "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"
  cwd     "#{node['storm']['install_dir']}"
  command "tar zxvf #{Chef::Config[:file_cache_path]}/storm-#{node['storm']['version']}.tar.gz"
end

# create a link from the specific version to a generic current folder
link "#{node['storm']['install_dir']}/current" do
	to "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"
end

# storm.yaml
template "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}/conf/storm.yaml" do
  source "storm.yaml"
  mode 00644
  variables(
    :nimbus => storm_nimbus,
    :zookeeper_quorum => zookeeper_quorum
  )
end

# sets up storm users profile
template "/home/storm/.profile" do
  owner  "storm"
  group  "storm"
  source "profile"
  mode   00644
  variables(
    :storm_dir => "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"
  )
end

template "#{install_dir}/bin/killstorm" do
  source  "killstorm.erb"
  owner "root"
  group "root"
  mode  00755
  variables({
    :log_dir => node['storm']['log_dir']
  })
end

