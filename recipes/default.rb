#
# Cookbook Name:: users
# Recipe:: default
#
# Copyright 2013, Joe Yates

# ruby-shadow is required for setting user passwords
gem_package 'ruby-shadow'

user_names = data_bag('users')

defaults = {
  'public_keys' => [],
  'accesses'    => [],
  'files'       => [],
  'directories' => [],
  'attributes'  => {},
}
default_attributes = {
  'admin'       => false,
}

users = user_names.reduce({}) do |a, name|
  data = Chef::EncryptedDataBagItem.load('users', name).to_hash
  data = defaults.merge(data)
  data['attributes'] = data['attributes'].merge(default_attributes)
  if name == 'root'
    data['accesses'] = []
    data['home'] = '/root'
    data['attributes']['admin'] = false
  else
    data['home'] = File.join('/home', name)
    data['accesses'].reject! { |name| name == 'root' }
  end
  a[name] = defaults.merge(data)
  a
end

# allow users ssh access to deploy users
# indicated in their 'accesses' array
def prepare_deploy_access(users)
  users.each do |name, u|
    u['accesses'].each do |user|
      unless users.include?(user)
        raise "User #{u['id']} accesses inexistent user #{user}"
      end
      users[user]['public_keys'] += u['public_keys']
    end
  end
end

def create_user(name, u)
  home_dir        = u['home']
  ssh_dir         = File.join(home_dir, '.ssh')
  authorized_keys = File.join(ssh_dir, 'authorized_keys')

  user u['id'] do
    shell       u['shell'] || '/bin/bash'
    home        home_dir
    supports    :manage_home => true
    not_if      "test -d #{home_dir}"
    not_if      { name == 'root' }
  end

  user "set #{u['id']}'s password" do
    username    u['id']
    password    u['password']
    not_if      { u['password'].nil? }
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

  u['files'].each do |f|
    pathname = File.join(home_dir, f['path'])
    file pathname do
      content     f['content']
      owner       u['id']
      group       u['id']
      mode        f['mode']
    end
  end

  u['directories'].each do |d|
    full_path = File.join(home_dir, d['path'])
    directory full_path do
      owner      d['user']    || u['id']
      group      d['group']   || u['id']
      mode       d['mode']    || 0700
    end
  end
end

prepare_deploy_access users

users.each do |name, u|
  create_user name, u
end

# sudo

admins = users.values.select { |u| u['attributes']['admin'] }
admin_usernames = admins.map { |u| u['id'] }

['admin', 'adm'].each do |g|
  group g do
    action      :create
    members     admin_usernames
  end
end

