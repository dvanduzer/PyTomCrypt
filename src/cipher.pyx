
from cpython cimport PyBytes_FromStringAndSize

from tomcrypt._core cimport *
from tomcrypt._core import Error

def test_library():
    """Run internal libtomcrypt cipher tests."""
    % for name in cipher_names:
    % if not name.endswith('_enc'):
    check_for_error(${name}_test())
    % endif
    % endfor
    check_for_error(eax_test())
        

# Register all the ciphers.
cdef int max_cipher_idx = -1
% for name in cipher_names:
max_cipher_idx = max(max_cipher_idx, register_cipher(&${name}_desc))
% endfor


cdef int get_cipher_idx(object input):
    idx = -1
    if isinstance(input, str):
        input = {
            'des3': '3des',
            'kseed': 'seed',
            'rijndael': 'aes', # This one is not cool.
            'saferp': 'safer+',
        }.get(input, input)
        idx = find_cipher(input)
    elif isinstance(input, Descriptor):
        idx = input.idx
    if idx < 0 or idx > max_cipher_idx:
        raise Error('could not find cipher %r' % input)
    return idx


cdef class Descriptor(object):
    """LibTomCrypt descriptor of a symmetric cipher.
    
    Can be called as convenience to calling Cipher, passing the cipher name
    via kwargs.
    
    """
    
    def __init__(self, cipher):
        self.idx = get_cipher_idx(cipher)
        self.desc = &cipher_descriptors[self.idx]
        
    def __repr__(self):
        return ${repr('<%s.%s of %s>')} % (
            self.__class__.__module__, self.__class__.__name__, self.desc.name)
                
    % for name in cipher_properties:
    @property
    def ${name}(self):
        return self.desc.${name}
    
    % endfor
    ##
    def key_size(self, key_size):
        cdef int out
        out = key_size
        check_for_error(self.desc.key_size(&out))
        return out
    
    def __call__(self, *args, **kwargs):
        return Cipher(*args, cipher=self.name, **kwargs)
    



# Define a type to masquarade as ANY of the mode states.
cdef union symmetric_all:
    % for mode in cipher_no_auth_modes:
    symmetric_${mode} ${mode}
    % endfor
    % for mode in cipher_auth_modes:
    ${mode}_state ${mode}
    % endfor


cdef class Cipher(Descriptor):
    """All state required to encrypt/decrypt with a symmetric cipher.
    
    Parameters:
        key: Symmetric key.
        iv: IV; None is treated as all null bytes.
        cipher: The name of the cipher to use; defaults to "aes".
        mode: Cipher block chaining more to use; defaults to "ctr".
    
    Mode Specific Parameters:
        tweak: Only for "lrw" mode.
        salt_key: Only for "f8" mode.
    
    """
    
    cdef symmetric_all state
    cdef readonly object mode
    cdef int mode_i
    
    def __init__(self, key, iv=None, cipher='aes', mode='ctr', **kwargs):
        self.mode = mode
        ## We must keep these indices as magic numbers in the source.
        self.mode_i = {
        % for mode, i in cipher_mode_items:
            ${repr(mode)}: ${i},
        % endfor
        }.get(self.mode, -1)
        if self.mode_i < 0:
            raise Error('no mode %r' % mode)
        Descriptor.__init__(self, cipher)
        self.start(key, iv, **kwargs)
    
    def __repr__(self):
        return ${repr('<%s.%s with %s in %s mode at 0x%x>')} % (
            self.__class__.__module__, self.__class__.__name__, self.name,
            self.mode, id(self))
    
    def start(self, key, iv=None, **kwargs):
        # Both the key and the iv are "const" for the start functions, so we
        # don't need to worry about making unique ones.
        
        if iv is None:
            iv = '\0' * self.desc.block_size
        if not isinstance(iv, str) or len(iv) != self.desc.block_size:
            raise Error('iv must be %d bytes' % self.desc.block_size)
        
        % for mode, i in cipher_mode_items:
        ${'el' if i else ''}if self.mode_i == ${i}: # ${mode}
            % if mode == 'ecb':
            check_for_error(ecb_start(self.idx, key, len(key), 0, <symmetric_${mode}*>&self.state))
            
            % elif mode == 'ctr':
            check_for_error(ctr_start(self.idx, iv, key, len(key), 0, CTR_COUNTER_BIG_ENDIAN, <symmetric_${mode}*>&self.state))
            
            % elif mode in cipher_simple_modes:
            check_for_error(${mode}_start(self.idx, iv, key, len(key), 0, <symmetric_${mode}*>&self.state))
            
            % elif mode == 'lrw':
            tweak = kwargs.get('tweak')
            if not isinstance(tweak, str) or len(tweak) != 16:
                raise Error('tweak must be 16 byte string')
            check_for_error(${mode}_start(self.idx, iv, key, len(key), tweak, 0, <symmetric_${mode}*>&self.state))
            
            % elif mode == 'f8':
            salt_key = kwargs.get('salt_key')
            if not isinstance(salt_key, str):
                raise Error('salt_key must be a string')
            check_for_error(${mode}_start(self.idx, iv, key, len(key), salt_key, len(salt_key), 0, <symmetric_${mode}*>&self.state))
            
            % elif mode == 'eax':
            nonce = kwargs.get('nonce', iv)
            if not isinstance(nonce, str):
                raise Error('nonce must be a string')
            header = kwargs.get('header', '')
            if not isinstance(header, str):
                raise Error('header must be a string')
            check_for_error(eax_init(<eax_state*>&self.state, self.idx,
                key, len(key),
                nonce, len(nonce),
                header, len(header),
            ))

            % else:
            raise Error('no start for mode %r' % ${repr(mode)})
            
            % endif
        % endfor
    ##
    cpdef get_iv(self):
        cdef unsigned long length
        length = self.desc.block_size
        iv = PyBytes_FromStringAndSize(NULL, length)
        % for i, (mode, mode_i) in enumerate(sorted(cipher_iv_modes.items())):
        ${'el' if i else ''}if self.mode_i == ${mode_i}: # ${mode}
            check_for_error(${mode}_getiv(iv, &length, <symmetric_${mode}*>&self.state))
        % endfor
        else:
            raise Error('%r mode does not use an IV' % self.mode)
        return iv
    
    cpdef set_iv(self, iv):        
        % for i, (mode, mode_i) in enumerate(sorted(cipher_iv_modes.items())):
        ${'el' if i else ''}if self.mode_i == ${mode_i}: # ${mode}
            check_for_error(${mode}_setiv(iv, len(iv), <symmetric_${mode}*>&self.state))
        % endfor
        else:
            raise Error('%r mode does not use an IV' % self.mode)
    
    cpdef add_header(self, str header):
        if self.mode_i != ${repr(cipher_modes['eax'])}:
            raise Error('add_header only works for EAX mode')
        check_for_error(eax_addheader(<eax_state*>&self.state, header,
            len(header)))

    % for type in 'encrypt decrypt'.split():
    cpdef ${type}(self, input):
        """${type.capitalize()} a string."""
        cdef int length
        length = len(input)
        # We need to make sure we have a brand new string as it is going to be
        # modified. The input will not be, so we can use the python one.
        output = PyBytes_FromStringAndSize(NULL, length)
        % for mode, i in cipher_mode_items:
        ${'el' if i else ''}if self.mode_i == ${i}: # ${mode}
            % if mode in cipher_auth_modes:
            check_for_error(${mode}_${type}(<${mode}_state*>&self.state, input, output, length))
            % else:
            check_for_error(${mode}_${type}(input, output, length, <symmetric_${mode}*>&self.state))
            % endif
        % endfor
        return output
    
    % endfor

    cpdef done(self):
        cdef unsigned long length = 1024

        % for mode, i in cipher_mode_items:
        ${'el' if i else ''}if self.mode_i == ${i}: # ${mode}
            % if mode == "eax":
            output = PyBytes_FromStringAndSize(NULL, length)
            check_for_error(eax_done(<eax_state*>&self.state, output, &length))
            return output[:length]
            
            % else    :
            check_for_error(${mode}_done(<symmetric_${mode}*>&self.state))

            % endif
        % endfor

    


names = ${repr(set(cipher_names))}
modes = ${repr(set(cipher_modes.keys()))}

% for name in cipher_names:
${name} = Descriptor(${repr(name)})
% endfor
