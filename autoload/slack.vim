let s:save_cpo = &cpo
set cpo&vim

if !executable('curl')
  echohl ErrorMsg | echomsg "Slack: require 'curl' command" | echohl None
  finish
endif

if globpath(&rtp, 'autoload/webapi/http.vim') == ''
  echohl ErrorMsg | echomsg "Slack: require 'webapi', install https://github.com/mattn/webapi-vim" | echohl None
finish
endif

if !exists('g:slack_channels')
  let g:slack_channels = {}
endif

if !exists('g:slack_debug')
  let g:slack_debug = 0
endif

if !exists('g:slack_link_names')
  let g:slack_link_names = 0
endif

if !exists('g:slack_incoming_token')
  let g:slack_incoming_token = ''
endif

if !exists('g:slack_fileupload_token')
  let g:slack_fileupload_token = ''
endif

if !exists('g:slack_channel_ids')
  let g:slack_channel_ids = {}
endif

let s:slack_req_params = [
  \ 'channel', 'username', 'text', 'icon_emoji'
  \]

let s:slack_channels = {}

function! slack#complete(lead, cmd, pos)
  let args = map(copy(s:slack_req_params), '"-" . v:val . "="')
  return filter(args, 'v:val =~# "^".a:lead')
endfunction

function! s:shellwords(str)
  " File: gist.vim
  " Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
  " License: BSD
  " see: https://github.com/mattn/gist-vim/blob/master/autoload/gist.vim#L112
  let words = split(a:str, '\%(\([^ \t\''"]\+\)\|''\([^\'']*\)''\|"\(\%([^\"\\]\|\\.\)*\)"\)\zs\s*\ze')
  let words = map(words, 'substitute(v:val, ''\\\([\\ ]\)'', ''\1'', "g")')
  let words = map(words, 'matchstr(v:val, ''^\%\("\zs\(.*\)\ze"\|''''\zs\(.*\)\ze''''\|.*\)$'')')

  return words
endfunction

function! s:get_visual_text()
  let text = ''
  let mode = visualmode(1)
  if mode == 'v' || mode == 'V' || mode == ''
    let start_lnum = line("'<")
    let end_lnum = line("'>")
    let lines = getline(start_lnum, end_lnum)
    let text = join(lines, "\n")
  endif

  return text
endfunction

function! s:build_payload(args, text)
  let payloads = {}
  let words = s:shellwords(a:args)
  let i = 0
  for word in words
    if word =~ '^-text='
      if a:text == ''
        let values = split(word, '=')
        if len(values) == 1
          " Multiple words.
          let text = words[i + 1]
        else
          " Single word.
          let text = values[1]
        endif
        let payloads['text'] = text
      endif
    elseif word =~ '^-[a-z]+\='
      let values = split(word, '=')
      if len(values) > 0
        let value = values[1]
      endif
      let key = substitute(values[0], '^-', '', '')
      let payloads[key] = value
    endif
    let i = i + 1
  endfor
  if a:text != ''
    let payloads['text'] = a:text
  endif

  if !has_key(payloads, 'text')
    " No command line args.
    " POST current buffer.
    let content = join(getline(1, line('$')), "\n")
    let payloads['content'] = content
  endif

  if !has_key(payloads, 'channel')
  elseif payloads['channel'] !~ '^#'
    let payloads['channel'] = '#' . payloads['channel']
  endif

  if has_key(payloads, 'icon_emoji') && payloads['icon_emoji'] !~ '^:'
    let payloads['icon_emoji'] = ':' . payloads['icon_emoji']
  endif
  if has_key(payloads, 'icon_emoji') && payloads['icon_emoji'] !~ ':$'
    let payloads['icon_emoji'] = payloads['icon_emoji'] . ':'
  endif
  if !has_key(payloads, 'username')
    let payloads['username'] = 'Slack.vim'
  endif

  if g:slack_link_names == 1
    let payloads['link_names'] = 1
  endif

  return payloads
endfunction

function! slack#post(...)
  redraw | echon 'Updating Slack... '
  let text = s:get_visual_text()
  let payloads = s:build_payload(a:000[0], text)

  if !has_key(payloads, 'channel')
    echohl ErrorMsg | echomsg 'Channel not found.' | echohl None
    return
  endif

  let key = payloads['channel']
  if has_key(g:slack_channels, key)
    let uri = g:slack_channels[key]
  else
    if g:slack_incoming_token == ''
      echohl ErrorMsg | echomsg 'Token not found.' | echohl None
      return
    else
      let uri = g:slack_incoming_token
    endif
  endif
  if has_key(payloads, 'content')
    if g:slack_fileupload_token == ''
      echohl ErrorMsg | echomsg 'File upload token is not found. Generate token from https://api.slack.com/#auth' | echohl None
      return
    endif
  endif

  let data = webapi#json#encode(payloads)
  if g:slack_debug == 1
    echomsg data
  endif
  let response = webapi#http#post(uri, data, {'Content-Type': 'application/json'})
  if response['status'] =~ '^2'
    redraw | echomsg 'Done: ' . response['message']
  else
    echohl ErrorMsg | echomsg 'Post failed: ' . response['content'] | echohl None
  endif
endfunction

function! slack#channel_id()
  let uris = {
    \ 'channels': 'https://slack.com/api/channels.list',
    \ 'groups': 'https://slack.com/api/groups.list'
    \ }
  let data = {
    \ 'token': g:slack_fileupload_token,
    \ }

  let channels = {}
  for k in keys(uris)
    let response = webapi#http#post(uris[k], data)
    let contents = webapi#json#decode(response.content)
    for c in contents[k]
      let channels[printf('#%s', c['name'])] = c['id']
    endfor
  endfor
  let s:slack_channels = channels

  return channels
endfunction

function! slack#file(...)
  """ WIP...
  if g:slack_fileupload_token == ''
    echohl ErrorMsg | echomsg 'File upload token is not found. Generate token from https://api.slack.com/#auth' | echohl None
    return
  endif
  redraw | echon 'Updating Slack... '
  let text = s:get_visual_text()
  let payloads = s:build_payload(a:000[0], text)
  if !has_key(payloads, 'channel')
    echohl ErrorMsg | echomsg 'Channel not found.' | echohl None
    return
  endif
  let filename = bufname('%')
  let ftype = &filetype
  let channel = payloads['channel']
  let content = payloads['content']
  let data = {
    \ 'token': g:slack_fileupload_token,
    \ }

  " Check global channel ids first.
  " If global was not found, try to get channel ids from API.
  let channel_id = ''
  if len(keys(g:slack_channel_ids)) > 0
    if has_key(g:slack_channel_ids, channel)
      let channel_id = g:slack_channel_ids[channel]
    endif
  else
    if len(keys(s:slack_channels)) == 0
      call slack#channel_id()
    endif
    if has_key(s:slack_channels, channel)
      let channel_id = s:slack_channels[channel]
    endif
  endif

  if channel_id == ''
    echohl ErrorMsg | echomsg 'Channel not found.' | echohl None
    return
  endif
  let data = {
    \ 'token': g:slack_fileupload_token,
    \ 'content': content,
    \ 'filetype': ftype,
    \ 'filename': filename,
    \ 'channels': channel_id
    \ }

  let uri = 'https://slack.com/api/files.upload'
  let response = webapi#http#post(uri, data)
  if response['status'] =~ '^2'
    redraw | echomsg 'Done: ' . response['message']
  else
    echohl ErrorMsg | echomsg 'Post failed: ' . response['content'] | echohl None
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
