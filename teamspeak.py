# -*- coding: utf-8 -*-
import getpass
import sys
import telnetlib
print "started"
HOST = "teamspeak.xn--smst-loa.se"
user = sys.argv[2]
password = sys.argv[3]

tn = telnetlib.Telnet(HOST, 10011)

print tn.read_until("command.")
tn.write("login " + user + " " + password)
tn.write("\r\n".encode('ascii'))
print tn.read_until(" msg=ok")
tn.write("use 1")
tn.write("\r\n".encode('ascii'))
print tn.read_until(" msg=ok")
tn.write("whoami")
tn.write("\r\n".encode('ascii'))
ret = tn.read_until(" msg=ok")
print ret
index = ret.find("client_id=")
client_id = ret[index+10:].split(" ")[0]
print "client id is " + client_id
tn.write("channelfind pattern=Bolagsmännens kontor")
tn.write("\r\n".encode('ascii'))
ret = tn.read_until(" msg=ok")
index = ret.find("cid=")
channel_id = ret[index+4:].split(" ")[0]
print "channel id is " + channel_id
tn.write("clientmove cid=" + channel_id + " clid=" + client_id)
tn.write("\r\n".encode('ascii'))
print tn.read_until(" msg=ok")
tn.write("sendtextmessage targetmode=2 msg=" + sys.argv[1])
tn.write("\r\n".encode('ascii'))
print tn.read_until(" msg=ok")
tn.write("quit")
tn.write("\r\n".encode('ascii'))
print tn.read_all()
