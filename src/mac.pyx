
from tomcrypt._core cimport *
from tomcrypt._core import Error
from tomcrypt.cipher cimport Descriptor as CipherDescriptor
from tomcrypt.cipher cimport get_cipher_idx
from tomcrypt.hash cimport Descriptor as HashDescriptor
from tomcrypt.hash cimport get_hash_idx

# Just making sure that everything is registered.
import tomcrypt.cipher
import tomcrypt.hash

def test_library():
    """Run internal libtomcrypt mac tests."""
    % for mac in mac_names:
    check_for_error(${mac}_test())
    % endfor


# A data type to hold ALL of the different mac type states.
cdef union mac_state:
    % for mac in mac_names:
    ${mac}_state ${mac}
    % endfor


cdef class MAC(object):
    
    cdef readonly object mode
    cdef int mode_i
    cdef readonly bint uses_hash
    cdef readonly bint uses_cipher
    
    cdef readonly object desc
    
    cdef mac_state state
    cdef object key
    
    def __init__(self, mode, idx, key, input=''):
        self.mode = mode
        % for mac, i in mac_items:
        ${'el' if i else ''}if mode == ${repr(mac)}:
            self.mode_i = ${i}
        % endfor
        else:
            raise Error('no MAC mode %r' % mode)
        
        self.uses_hash = self.mode in ${repr(hash_macs)}
        self.uses_cipher = not self.uses_hash
        
        if self.uses_hash:
            self.desc = HashDescriptor(idx)
        else:
            self.desc = CipherDescriptor(idx)
        
        self.key = key
        
        
        % for mac, i in mac_items:
        ${'el' if i else ''}if self.mode_i == ${i}: # ${mac}
            check_for_error(${mac}_init(<${mac}_state *>&self.state, self.desc.idx, key, len(key)))
        % endfor
        
        
        self.update(input)
    
    def __dealloc__(self):
        if self.mode_i == ${mac_ids['hmac']}:
            free(self.state.hmac.key)
    
    def __repr__(self):
        return ${repr('<%s.%s of %s using %s at 0x%x>')} % (
            self.__class__.__module__, self.__class__.__name__, self.mode,
            self.desc.name, id(self))
    
    cpdef update(self, str input):
        % for mac, i in mac_items:
        ${'el' if i else ''}if self.mode_i == ${i}: # ${mac}
            check_for_error(${mac}_process(<${mac}_state *>&self.state, input, len(input)))
        % endfor
    
    cpdef digest(self, length=None):
        if length is None:
            if self.uses_hash:
                length = self.desc.digest_size
            else:
                length = self.desc.block_size
        cdef unsigned long c_length = length
        
        # Make a copy of the hmac state and all of it's parts. We need to do
        # this because the *_done function mutates the state. The key is
        # deallocated so we aren't causing a memory leak here.
        cdef mac_state state
        memcpy(&state, &self.state, sizeof(mac_state))
        
        if self.mode_i == ${mac_ids['hmac']}:
            state.hmac.key = <unsigned char *>malloc(self.desc.block_size)
            memcpy(state.hmac.key, self.state.hmac.key, self.desc.block_size)
        
        out = PyBytes_FromStringAndSize(NULL, c_length)
        
        % for mac, i in mac_items:
        ${'el' if i else ''}if self.mode_i == ${i}: # ${mac}
            check_for_error(${mac}_done(<${mac}_state *>&state, out, &c_length))
        % endfor
        
        return out[:c_length]
    
    cpdef hexdigest(self, length=None):
        return self.digest(length).encode('hex')
    
    cpdef copy(self):
        cdef MAC copy = self.__class__(self.mode, self.desc, self.key)
        memcpy(&copy.state, &self.state, sizeof(mac_state))
        
        if self.mode_i == ${mac_ids['hmac']}:
            copy.state.hmac.key = <unsigned char *>malloc(self.desc.block_size)
            memcpy(copy.state.hmac.key, self.state.hmac.key, self.desc.block_size)
        
        return copy


hash_macs = ${repr(hash_macs)}
cipher_macs = ${repr(cipher_macs)}
names = ${repr(set(mac_names))}

% for name in mac_names:
def ${name}(*args, **kwargs): return MAC(${repr(name)}, *args, **kwargs)
% endfor
