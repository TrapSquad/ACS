#!/usr/bin/env tclsh
# ACS client
package require rc4
package require base64
package require md5
if {[lindex $::argv 0] == ""} {puts stdout "Pls specify an IP.";exit}
if {[lindex $::argv 1] == ""} {puts stdout "Pls specify a port.";exit}

proc dosock {} {
	if {[eof $::sock]} {exit}
	gets $::sock puto
	set putou [::base64::decode $puto]
	set putout [::rc4::RC4 $::km $putou]
	set put [dorc4dec $putout]
	if {$put == ""} {} {puts stdout $put}
}

proc dopad {str} {
	set padlen [expr {16-([string length $str]%8)}]
	append str [string repeat "\0" $padlen]
	return str
}

proc dorc4 {toml str} {
	set putout "MLMSG "
	append putout [::md5::md5 -hex $str]
	append putout " "
	set lkm [::rc4::RC4Init $toml]
	append putout [::base64::encode -maxlen 1024 [::rc4::RC4 $lkm $str]]
	::rc4::RC4Final $lkm
	return $putout
}

proc arcfour {toml str} {
	set lkm [::rc4::RC4Init $toml]
	set putout [::base64::encode -maxlen 1024 [::rc4::RC4 $lkm $str]]
	::rc4::RC4Final $lkm
	return $putout
}

proc dorc4dec {str} {
	set line [split $str " "]
	set cksum [lindex $line 1]
	set txt [::base64::decode [lindex $line 2]]
	if {[lindex $line 0] != "MLMSG"} {return "GLOBMSG :$str"}
	foreach {ml is} [array get ::ml] {
		if {$is != 1} {continue}
		set dectest [::base64::decode [arcfour $ml $txt]]
		if {[::md5::md5 -hex $dectest] != $cksum} {continue} {
			return "MLMSG $ml :$dectest"
		}
	}
}

set ml(0) 0

proc dostdin {} {
	global ml
	gets stdin line
	set stuff [split $line " "]
	switch -nocase -exact -- [lindex $stuff 0] {
		"MLMSG" {
			set str [join [lrange $stuff 2 end] " "]
			set toml [lindex $stuff 1]
			puts $::sock [::base64::encode -maxlen 1024 [::rc4::RC4 $::km [dorc4 $toml $str]]]
		}
		"MLADD" {
			set ml([lindex $stuff 1]) 1
		}
		"MLDEL" {
			set ml([lindex $stuff 1]) 0
		}
		"GLOBMSG" {
			set putout [::base64::encode -maxlen 1024 [::rc4::RC4 $::km [join [lrange $stuff 1 end] " "]]]
			puts $::sock $putout
		}
	}
}

puts -nonewline stdout "What encryption key would you like to use? "
flush stdout
set key [gets stdin]
puts stdout ""

set sock [socket [lindex $::argv 0] [lindex $::argv 1]]
set km [::rc4::RC4Init $::key]
fconfigure $sock -buffering line -buffersize 1024
fconfigure stdin -buffering line -buffersize 1024
fileevent $sock readable dosock
fileevent stdin readable dostdin
vwait NeverSet
