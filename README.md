users-cookbook
==============
Creates system users based on attributes in data bags.

# Setup

Add
```ruby
gem 'knife-solo_data_bag'
```
to your Gemfile.

# Attributes

The default attributes are:

`list` indicates which of the users in your data bags should actually be created.
The default is the special value '*', which means *all*.

Note: if `list` is set to an empty array, no users will be created.

```ruby
default['users']['list'] = ['*']
```

Each user can be configured to accept ssh access with the private keys of
other users (see below). This is a hash mapping taget users to an array of
others who can access that user.

```ruby
default['users']['accessed_by'] = {}
```

```ruby
default['users']['sudo_groups'] = %w(sudo admin)
```

Override defaults by setting the `users` hash:

```json
"users": {
  "list": ["fred", "bill"],
  "accessed_by": {"bill": ["fred"]}
}
```

# Editing User Data

In the root of your kitchen:

## Create a data bag
```shell
mkdir data_bags
knife solo data bag create users USERNAME
```

## Export data
The following command will give you a JSON string that, when wrapped in single
quotes can be re-imported into a data bag:

```shell
knife solo data bag show users USERNAME -F json > JSON_FILE
```

## Import data
Create a new data bag with data exported via the previous step:

```shell
knife solo data bag create users USERNAME --json-file JSON_FILE
```

## Data structure

An example of the expected data bag structure is as follows:
```json
{
  "id": "USER_NAME",
  "password": "...",
  "home": "...",
  "attributes": {
    "admin": false
  },
  "groups": ["fred"],
  "public_keys": [
    "ssh-rsa ..."
  ],
  "accessed_by": [
    "OTHER USER NAME"
  ],
  "files": [
    {
      "path": "FILE NAME RELATIVE TO USER'S HOME",
      "mode": "0644",
      "content": "THE FILE CONTENT"
    }
  ],
  "directories": [
    {
      "path": "bin",
      "mode": "0770"
    }
  ]
}
```

* `id`        - (required) the user name
* `password`  - encoded password (see below)
* `home`      - home directory (default to "/home/username" or "/root")
* `attributes`:
    * `admin`     - when truthy, adds the user to sudoers
* `groups`    - a list of extra groups to add the user to,
* `files`     - install user files,
  You can specify the following:
    * path      - (required) the name of the file relative to the user's home,
    * mode      - file permissions, default: "0644",
    * content   - (required) the text to put inside the file.
* `directories` - create directories,
  You can specify the following:
    * path      - (required) the name of the directory relative to the user's home,
    * mode      - file permissions, default: "0700".
* `accessed_by`  - an array of other users. This user's public keys will be copied to the
  other user's `authorized_keys` files allowing this user to log on as them.

Make an encoded password:
This requires the program 'mkpasswd' which, on Debian systems, is part of the 'whois' package.

```
$ mkpasswd --method=sha-512
```

### root

root is treated as special:

* no home created/managed,
* no sudo access configured,
* `accessed_by` is ignored,
* other users cannot access root via SSH, unless their public key is installed
  manually by root.

Remember to add the chef deploy key to root's public keys.
