#!/bin/sh

(
printf "%b\n" 'root,^tag(root)'
printf "%b\n" 'a,^checkout(a)'
printf "%b\n" 'b,^checkout(b)'
printf "%b\n" 'c,^checkout(c)'
printf "%b\n" 'a,^tag(a)'
printf "%b\n" 'aa,^checkout(aa)'
printf "%b\n" 'ab,^checkout(ab)'
printf "%b\n" 'a1'
printf "%b\n" 'a2'
printf "%b\n" 'a3'
printf "%b\n" 'aa,^tag(aa)'
printf "%b\n" 'aa1'
printf "%b\n" 'aa1'
printf "%b\n" 'ab,^tag(ab)'
printf "%b\n" 'ab1'
printf "%b\n" 'ab1'
printf "%b\n" 'b,^tag(b)'
printf "%b\n" 'b1'
printf "%b\n" 'b2'
printf "%b\n" 'c,^tag(c)'
printf "%b\n" 'c1'
printf "%b\n" 'c2'
) | ../jgmenu --config-file=./ex02-jgmenurc
