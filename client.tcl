#!/usr/bin/env tclsh
# ACS client
package require rc4
package require base64
package require md5
if {[lindex $::argv 0] == ""} {puts stdout "Pls specify an IP.";exit}
if {[lindex $::argv 1] == ""} {puts stdout "Pls specify a port.";exit}

proc dosock {} {
	if {[eof $::sock]} {exit}
	set putout "> "
	append putout [::rc4::RC4 $::km [::base64::decode [gets $::sock]]]
	puts stdout $putout
}

proc dopad {str} {
	set padlen [expr {16-([string length $str]%8)}]
	append str [string repeat "\0" $padlen]
	return str
}

proc dostdin {} {
	set putout [::base64::encode [::rc4::RC4 $::km [gets stdin]]]
	puts $::sock $putout
}

puts -nonewline stdout "What encryption key would you like to use? "
flush stdout
set key [gets stdin]
puts stdout ""

set sock [socket [lindex $::argv 0] [lindex $::argv 1]]
set km [::rc4::RC4Init $::key]
fconfigure $sock -buffering line
fconfigure stdin -buffering line
fileevent $sock readable dosock
fileevent stdin readable dostdin
vwait NeverSet
