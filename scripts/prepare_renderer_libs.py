#!/usr/bin/env python3
from pathlib import Path
from urllib.request import urlopen
import hashlib

base="https://raw.githubusercontent.com/herbrine8403/Amethyst-iOS-MyRemastered/6514be64b8d414289f53922f0f30d626542e2471/Natives/resources/Frameworks/"
files={
"libshaderc.dylib":"f52756d2c010cfbb3a2e24555f4ece9b293567e5797ac855789a91392549b2f1",
"libvirgl_test_server.dylib":"4c0a81dbd79c77e633b42e4d2a47956fea00f4b599a7a2d40640ba5c823502c7"}

for name,want in files.items():
    data=urlopen(base+name,timeout=120).read()
    if hashlib.sha256(data).hexdigest()!=want:
        raise RuntimeError(name+" 校验失败")
    Path("depends/Frameworks",name).write_bytes(data)
    print(name,"准备完成")
