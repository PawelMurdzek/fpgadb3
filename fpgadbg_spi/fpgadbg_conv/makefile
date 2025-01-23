all:    _lxt.so lxt.py
# You may need to modify the -I/usr/include/python2.3 option
# To match your particular distribution
_lxt.so lxt.py: lxt_write.c lxt_write.h lxt_write.i
	swig -python lxt_write.i
	gcc -shared -I/usr/include/python3.11 lxt_write_wrap.c lxt_write.c -o _lxt.so -lz -lbz2 -lnsl

clean:
	#rm *.o _lxt.so lxt.py *.pyc lxt_write_wrap.c
	rm _lxt.so lxt.py lxt_write_wrap.c
