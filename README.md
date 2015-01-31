Slack for Vim
=============

This is a Vim plugin for post message to [Slack](https://slack.com/)

Currently this plugin is work in progress.

Usage
-----

- Post message via command line.

  ```viml
  :Slack -channel=#general -text="Hello world"
  ```

  Post `Hello world` to #general channel

- Post current buffer to Slack.

  ```viml
  :Slack -channel=#general
  ```

  Post current buffer texts to #general channel

- Post visual selected texts.

  ```viml
  :'<,'>Slack -channel=#general
  ```

  Post visual selected texts to #general channel

- Post message specific username

  ```viml
  :'<,'>Slack -channel=#general -username=Vimmer
  ```

- Post message specific username

  ```viml
  :'<,'>Slack -channel=#general -username=Vimmer
  ```

- Upload current buffer as a file.
  ```viml
  :SlackFile -channel=#general
  ```

- Upload selected text as a file.
  ```viml
  :'<,'>SlackFile -channel=#general
  ```
Requirement
-----------
This plugin need [webapi-vim](https://github.com/mattn/webapi-vim).
