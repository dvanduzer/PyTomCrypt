from __future__ import print_function

cimport cpython

import re
import base64

from tomcrypt._core cimport *
from . import Error


def pem_encode(type, mode, content):
    """PEM encode a key.

    :param str type: ``"RSA"``, ``"EC"``, etc.
    :param str mode: ``"PUBLIC"`` or ``"PRIVATE"``
    :param bytes content: The content to encode.

    >>> print(pem_encode('TEST', 'PRIVATE', b'private content'))
    -----BEGIN TEST PRIVATE KEY-----
    cHJpdmF0ZSBjb250ZW50
    -----END TEST PRIVATE KEY-----

    >>> print(pem_encode('TEST', 'PUBLIC', b'public content'))
    -----BEGIN PUBLIC KEY-----
    cHVibGljIGNvbnRlbnQ=
    -----END PUBLIC KEY-----

    """

    type = type.upper()
    mode = mode.upper()
    if mode not in ('PUBLIC', 'PRIVATE'):
        raise Error('mode must be PUBLIC or PRIVATE')
    type = ('%s %s' % (type, mode)) if mode == 'PRIVATE' else 'PUBLIC'
    content = str(base64.b64encode(content).decode())
    content = '\n'.join(content[i:i+78] for i in range(0, len(content), 78))
    return '-----BEGIN %(type)s KEY-----\n%(content)s\n-----END %(type)s KEY-----\n' % dict(
        type=type,
        content=content,
    )

_pem_re = re.compile(r"""
    ^\s*
    -----BEGIN\ (([A-Z]+\ )?(PUBLIC|PRIVATE))\ KEY-----
    (.+)
    -----END\ \1\ KEY-----
    \s*$
""", re.VERBOSE | re.DOTALL)


def pem_decode(content):
    """PEM decode a key.

    Returns a tuple of:
    
    - type: E.g. ``"RSA"``, ``"EC"``, or None (likely if public);
    - mode: ``"PRIVATE"`` or ``"PUBLIC"``;
    - content: original content.

    Throws a tomcrypt.Error if content is not PEM encoded.

    """

    m = _pem_re.match(content)
    if not m:
        raise Error('not PEM encoded')
    type, mode, content = m.group(2, 3, 4)
    type = type and type.rstrip().upper()
    mode = mode.upper()
    content = base64.b64decode(''.join(content.strip().split()).encode())
    return type, mode, content


def xor_bytes(a, b):
    """XOR two sequences of bytes.

    :param bytes a: One sequence of bytes.
    :param bytes b: Another sequence of bytes.
    :return bytes: A sequence of bytes, the same length of ``a`` and ``b``
        in which each byte is the XOR of the respective bytes from ``a`` and
        ``b``.

    :raises ValueError: When the byte sequences have different lengths.

    >>> xor_bytes(b'hello', b'world')
    b'\\x1f\\n\\x1e\\x00\\x0b'
    >>> xor_bytes(b'hello', b'hello')
    b'\\x00\\x00\\x00\\x00\\x00'

    """

    cdef ByteSource x = bytesource(a)
    cdef ByteSource y = bytesource(b)
    if x.length != y.length:
        raise ValueError('arguments must have matching lengths; given %d and %d' % (
            x.length, y.length
        ))

    cdef bytes res = cpython.PyBytes_FromStringAndSize(NULL, x.length)

    cdef unsigned long i
    for i in range(x.length):
        (<unsigned char*>res)[i] = x.ptr[i] ^ y.ptr[i]
    
    return res


def bytes_equal(a, b):
    """Constant-time byte sequence equality.

    Good for removing a huge potential timing attack.

    :param bytes a: One sequence of bytes.
    :param bytes b: Another sequence of bytes.
    :return bool: ``True`` if the sequences are the same.

    :raises ValueError: When the byte sequences have different lengths.

    >>> bytes_equal(b'hello', b'hello')
    True

    >>> bytes_equal(b'hello', b'world')
    False

    """

    cdef ByteSource x = bytesource(a)
    cdef ByteSource y = bytesource(b)
    if x.length != y.length:
        raise ValueError('arguments must have matching lengths; given %d and %d' % (
            x.length, y.length
        ))

    cdef unsigned int are_different = 0

    cdef unsigned long i
    for i in range(x.length):
        are_different |= x.ptr[i] ^ y.ptr[i]

    return not are_different


