let s:save_cpo = &cpo
set cpo&vim

command! -nargs=* -range=0 -complete=customlist,slack#complete Slack
  \ call slack#post(<q-args>, <count>, <line1>, <line2>)

let &cpo = s:save_cpo
unlet s:save_cpo
