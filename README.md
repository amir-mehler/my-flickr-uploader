# My Flickr Uplaoder

Ruby uploader to Flickr - based on flickraw

### Advantages

- upload everything!
- prevent duplications (I use MD5 sums and flickr IDs so you can move your pictures around, have them on two computers, whatever, it won't upload any picture twice)
- If you already have duplications - it can detect them for you so you can delete them
- upload videos too (flickr are not that strong with videos right now)

### Instructions

1. install ruby 2 (2.2 or 2.1 are ok).
2. run bundle install (install the bundle gem if you don't have it).
3. create a folder called `secret` and place the **api_key.yml** file I sent you in it.
4. create a config file for you user and put it in a `config` folder. For example, **amir-mehler.yml**: 
`
work_dirs:
  - "/Users/amirmlr/Pictures"
__comment__:
  - "must be full path starting at '/'"
  - "no importance for '/' at the end"`
5. start doing things like: 
```
$ bin/start_uploader --user amir-mehler```

### Also consider

1. changing the number of uploader threads (in the config.rb file)
2. log level, or log file instead of stdout (in the config.rb file)
3. hard code your username in the bin file and skip trollop
4. backing up the database to github like I do (it ends up very small and includes no private information)

### Change log

- nope
