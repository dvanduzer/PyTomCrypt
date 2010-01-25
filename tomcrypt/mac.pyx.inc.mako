

def test_mac():
	register_all_hashes()
	check_for_error(hmac_test());

			
cdef class hmac(HashDescriptor):
	
	cdef hmac_state state
	
	def __init__(self, hash, key, *args):
		HashDescriptor.__init__(self, hash)
		self.init(key)
		for arg in args:
			self.update(arg)
	
	def __repr__(self):
		return ${repr('<%s.%s of %s at 0x%x>')} % (
			self.__class__.__module__, self.__class__.__name__, self.name,
			id(self))
	
	cpdef init(self, key):
		hmac_init(&self.state, self.idx, key, len(key))
	
	cpdef update(self, input):
		check_for_error(hmac_process(&self.state, input, len(input)))
	
	
	cpdef digest(self, length=None):
		if length is None:
			length = self.desc.digest_size
		cdef unsigned long c_len = length
		cdef hmac_state state
		memcpy(&state, &self.state, sizeof(hash_state))
		out = PyString_FromStringAndSize(NULL, self.desc.digest_size)
		check_for_error(hmac_done(&state, out, &c_len))
		return out[:c_len]
	
	def hexdigest(self, *args):
		return self.digest(*args).encode('hex')
	
	cpdef copy(self):
		cdef hmac copy = self.__class__(self.desc.name)
		memcpy(&copy.state, &self.state, sizeof(hmac_state))
		return copy
