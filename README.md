users-cookbook
==============
Creates system users based on attributes in data bags.

# Setup

Add
```
gem 'knife-solo_data_bag'
```
to your Gemfile.

# Editing User Data

In the root of your kitchen:

## Create a data bag
```
mkdir data_bags
knife solo data bag create users USERNAME
```

## Export data
The following command will give you a JSON string that, when wrapped in single
quotes can be re-imported into a data bag:

```
knife solo data bag show users USERNAME -F json > JSON_FILE
```

## Import data
Create a new data bag with data exported via the previous step:

```
knife solo data bag create users USERNAME --json-file JSON_FILE
```

## Data structure

An example of the expected data bag structure is as follows:
```json
{
  "id": "USER_NAME",
  "password": "...",
  "attributes": {
    "admin": false
  },
  "public_keys": [
    "ssh-rsa ..."
  ],
  "accesses": [
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

* id        - (required) the user name
* password  - encoded password (see below)
* attributes:
    * admin     - when truthy, adds the user to sudoers
* files     - install user files,
  You can specify the following:
    * path      - (required) the name of the file relative to the user's home,
    * mode      - file permissions, default: "0644",
    * content   - (required) the text to put inside the file.
* directories - create directories,
  You can specify the following:
    * path      - (required) the name of the directory relative to the user's home,
    * mode      - file permissions, default: "0700".
* accesses  - an array of other users. This user's public keys will be copied to the
  other user's authorized_keys files allowing this user to log on as them.

Make an encoded password:
This requires the program 'mkpasswd' which, on Debian systems, is part of the 'whois' package.

```
$ mkpasswd --method=sha-512
```

### root

root is treated as special:

* no home created/managed
* no sudo access configured
* no accesses configured
* other users cannot access root via SSH, unless their public key is installed by
  root.

Remember to add the chef deploy key to root's public_keys.

