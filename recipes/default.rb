#
# Cookbook Name:: users
# Recipe:: default
#
# Copyright 2013-2015, Joe Yates

# ruby-shadow is required for setting user passwords
gem_package 'ruby-shadow'

defaults = {
  'public_keys' => [],
  'files'       => [],
  'directories' => [],
  'groups'      => [],
  'symlinks'    => {},
  'attributes'  => {},
}
default_attributes = {
  'admin'       => false,
}


def all_users
  Chef::DataBag.load('users').keys
end

def users_to_create
  case node['users']['list']
  when '*'
    all_users
  when nil
    all_users
  else
    node['users']['list']
  end
end

# Allow users to access deploy users via SSH.
# Target users indicate permitted accesses in their 'accessed_by' array.
# Supplying `accessed_by` data for root causes a fatal error.
def prepare_deploy_access(user_data)
  node['users']['accessed_by'].each do |target, accessors|
    unless user_data.include?(target)
      raise "Cannot grant access to an inexistent user '#{target}'"
    end
    if target == 'root'
      raise "Can't create access to root user"
    end
    accessors.each do |accessor|
      unless user_data.include?(accessor)
        raise "Can't grant SSH access to user '#{target}' by user '#{accessor}' - no data bag found for user '#{accessor}'"
      end
      user_data[target]['public_keys'] += user_data[accessor]['public_keys']
    end
  end
end

def create_user(name, u)
  home_dir        = u['home']
  ssh_dir         = File.join(home_dir, '.ssh')
  authorized_keys = File.join(ssh_dir, 'authorized_keys')
  default_shell   = "/bin/bash"

  user u['id'] do
    action      :create
    shell       u['shell'] || default_shell
    home        home_dir
    supports    :manage_home => true
    not_if      "test -d #{home_dir}"
    not_if      { name == 'root' }
  end

  user "maintain #{u["id"]}'s shell" do
    action      :modify
    username    u["id"]
    shell       u["shell"]
    only_if     { u["shell"] }
    only_if     { u["shell"] != default_shell }
    only_if     "test -d #{home_dir}"
    # Is shell already set to the desired value?
    not_if      "grep '^#{u["id"]}' /etc/passwd | grep '#{u["shell"]}$' > /dev/null"
    not_if      { name == "root" }
  end

  user "set #{u['id']}'s password" do
    username    u['id']
    password    u['password']
    not_if      { u['password'].nil? }
  end

  u['groups'].each do |g|
    group g do
      action :modify
      members u['id']
      append true
    end
  end

  directory ssh_dir do
    owner       u['id']
    group       u['id']
    mode        '0700'
  end

  file authorized_keys do
    owner       u['id']
    group       u['id']
    mode        '0600'
    content     u['public_keys'].join("\n") + "\n"
  end

  u['directories'].each do |d|
    full_path = File.join(home_dir, d['path'])
    directory full_path do
      owner      d['user']    || u['id']
      group      d['group']   || u['id']
      mode       d['mode']    || 0700
    end
  end

  u['symlinks'].each do |link_name, destination|
    full_path = File.join(home_dir, link_name)
    link full_path do
      to destination
    end
  end

  u['files'].each do |f|
    pathname = File.join(home_dir, f['path'])
    file pathname do
      content     f['content']
      owner       u['id']
      group       u['id']
      mode        f['mode']
    end
  end
end

user_data = {}

users_to_create.each do |name|
  data = nil
  begin
    data = Chef::EncryptedDataBagItem.load('users', name).to_hash
  rescue Chef::Exceptions::ValidationFailed => e
    raise "Unable to load data bag users/#{name}. #{e}"
  end
  data = defaults.merge(data)
  data['attributes'] = default_attributes.merge(data['attributes'])
  if name == 'root'
    data['home'] ||= '/root'
    data['attributes']['admin'] = false
    data['accessed_by'] = []
  else
    data['home'] ||= File.join('/home', name)
  end
  user_data[name] = defaults.merge(data)
  if data.include?('accessed_by')
    node.override['users']['accessed_by'][name] = data['accessed_by']
  end
end

prepare_deploy_access user_data

user_data.each do |name, u|
  create_user name, u
end

# sudo

package "sudo"

admins = user_data.values.select { |u| u['attributes']['admin'] }
admin_usernames = admins.map { |u| u['id'] }

node['users']['sudo_groups'].each do |g|
  group g do
    action      :create
    members     admin_usernames
  end
end
