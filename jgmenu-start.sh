#!/bin/sh

cmd=$(jgmenu_run config --get csv_cmd)
test -z ${cmd} && cmd="jgmenu_run parse-pmenu"
exec ${cmd} | jgmenu --stay-alive --hide-on-startup