# dump.py -- dump DAPHNE spy buffers
# 
# in linux, you may need to configure your NIC card as root, something like this:
#
# $ ifconfig p3p1 192.168.133.99 netmask 255.255.255.0
# $ ip route add 192.168.133.0/24 dev p3p1
# 
# Jamieson Olsen <jamieson@fnal.gov>

from oei import *

thing = OEI("192.168.133.12")

print "DAPHNE firmware version %0X" % thing.read(0x9000,1)[2]

thing.write(0x2000, [1234]) # software trigger, all spy buffers capture

print

# note, ignore the FIRST word of the spy buffer, it stutters due to firmware bug
# will fix in next version...

for afe in range(5):
    for ch in range(9):
        print "AFE%d[%d]: " % (afe,ch),
        for x in thing.read(0x40000000+(afe*0x100000)+(ch*0x10000),20)[3:]:
            print "%04X" % x,
        print
    print
       
thing.close()

