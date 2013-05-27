bookrepublic-users Cookbook
===========================

# Setup

Add
```
gem 'knife-solo_data_bag'
```
to your Gemfile.

# Editing User Data

In the root of your kitchen:

Create a data bag:
```
mkdir data_bags
knife solo data bag create users USERNAME
```

