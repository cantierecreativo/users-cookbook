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
knife solo data bag show users USERNAME -F json | json_pp -json_opt canonical > JSON_FILE
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
    "bin"
  ]
}
```

* id        - (required) the user name
* password  - encoded password (echo 'PASSWORD' | mkpasswd -m sha-512 -s')
* attributes:
** admin     - when truthy, adds the user to sudoers
* files     - install user files
* accesses  - an array of other users. This user's public keys will be copied to the
  other user's authorized_keys files allowing this user to log on as them.

### root

root is treated as special:
* no home created/managed
* no sudo access configured
* no accesses configured
* other users cannot access root via SSH, unless their public key is installed by
  root.

Remember to add the chef deploy key to root's public_keys.

