cdef extern from "tomcrypt.h" nogil:

	% for mode in 'hmac', 'omac':
	ctypedef struct ${mode}_state:
		unsigned char *key # The block size of the hash.
	
	int ${mode}_test()
	int ${mode}_init(${mode}_state *, int, unsigned char *, unsigned long)
	int ${mode}_process(${mode}_state *, unsigned char *, unsigned long)
	int ${mode}_done(${mode}_state *, unsigned char *, unsigned long *)
	
	
	% endfor
