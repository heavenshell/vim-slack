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

let s:slack_req_params = [
  \ 'channel', 'username', 'text', 'icon_emoji'
  \]

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
  if words == [] || !has_key(words, 'text')
    " No command line args.
    " POST current buffer.
    let content = join(getline(1, line('$')), "\n")
  else
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
    if payloads['channel'] !~ '^#'
      let payloads['channel'] = '#' . payloads['channel']
    endif
    if has_key(payloads, 'icon_emoji') && payloads['icon_emoji'] !~ '^:'
      let payloads['icon_emoji'] = ':' . payloads['icon_emoji']
    endif
    if !has_key(payloads, 'username')
      let payloads['username'] = 'Slack.vim'
    endif

    if g:slack_link_names == 1
      let payloads['link_names'] = 1
    endif
  endif

  return payloads
endfunction

function! slack#post(...)
  redraw | echon 'Updating Slack... '
  let text = s:get_visual_text()
  let payloads = s:build_payload(a:000[0], text)
  let key = payloads['channel']

  let uri = g:slack_channels[key]
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

let &cpo = s:save_cpo
unlet s:save_cpo
