# Negative compile fixture: the removed public namespace must not resolve.
from mojoakku.codec_base64 import encode


def main():
    print(encode("foobar"))
