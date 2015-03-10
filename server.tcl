#!/usr/bin/env tclsh
# ACS server portion
# key is read from stdin
package require rc4
package require base64
package require md5
source nda.tcl
if {[lindex $::argv 0] == ""} {puts stdout "Pls specify a port.";exit}

set socks [list]
set km(1) 0

proc acs:server {sock addr port} {
	global socks km
	puts stdout "Accepted connection from $addr $port on $sock"
	fconfigure $sock -buffering line -buffersize 1024
	tnda set "socks/$sock/on" 1
	set km($sock) [::rc4::RC4Init $::key]
	fileevent $sock readable [list acs:main $sock $addr $port]
}

proc dopad {str} {
	set padlen [expr {8-([string length $str]%8)}]
	append str [string repeat \0 $padlen]
	return str
}

proc acs:main {sock addr port} {
	global km
	if {[eof $sock]} {global socks; tnda set "socks/$sock/on" 0; ::rc4::RC4Final $km($sock);close $sock;return}
	gets $sock stuff
	set got [::rc4::RC4 $km($sock) [::base64::decode $stuff]]
	set send $got
	if {$got == ""} {return}
	foreach {sck chk} [tnda get "socks"] {
		if {[dict get $chk on] != 1} {continue}
		if {$sck == $sock} {continue}
		set ssend [::rc4::RC4 $km($sck) $send]
		catch [list puts $sck [::base64::encode -maxlen 1024 $ssend]]
	}
}

puts -nonewline stdout "What encryption key would you like to use? "
flush stdout
set key [gets stdin]
puts stdout ""

socket -server acs:server [lindex $::argv 0]

vwait NeverSet
