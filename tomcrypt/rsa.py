
from ._main import (
    RSAKey as _Key,
    RSA_TYPE_PRIVATE as TYPE_PRIVATE,
    RSA_TYPE_PUBLIC as TYPE_PUBLIC,
    RSA_PAD_V1_5 as PAD_V1_5,
    RSA_PAD_OAEP as PAD_OAEP,
    RSA_PAD_PSS as PAD_PSS,
    RSA_FORMAT_PEM as FORMAT_PEM,
    RSA_FORMAT_DER as FORMAT_DER
)

class Key(_Key):
    
    def __repr__(self):
        return '<%s.%s(%s) at 0x%x>' % (self.__class__.__module__, 
            self.__class__.__name__,
            'public' if self.is_public else 'private',id(self))

