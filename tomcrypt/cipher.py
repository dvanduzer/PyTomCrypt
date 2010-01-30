
import sys

from ._main import (CipherDescriptor as _Descriptor, Cipher as _Cipher, cipher_names as ciphers,
	cipher_modes as modes, test_cipher as test)


self = sys.modules[__name__]


class Descriptor(_Descriptor):
	def __call__(self, key, *args, **kwargs):
		return Cipher(key, *args, cipher=self.name, **kwargs)

class Cipher(_Cipher):
	pass


for name in ciphers:
	try:
		self.__dict__[name] = Descriptor(name)
	except ValueError:
		pass

for mode in modes:
	def mode_constructor(key, *args, **kwargs):
		return Cipher(key, *args, mode=mode, **kwargs)
	mode_constructor.__name__ = mode
	self.__dict__[mode] = mode_constructor


new = Cipher