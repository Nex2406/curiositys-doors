"""Inline every image as a data URI, so the deck is ONE self-contained file.

    python docs/presentation/bake.py            -> docs/presentation/build/curiositys-doors.html

The repo copy (index.html) references img/*.jpg and is the one to edit. This
produces the single-file version for publishing / emailing / opening anywhere.
"""
import base64, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "index.html"), encoding="utf-8").read()
cache = {}


def _inline(m: "re.Match") -> str:
    rel, ext = m.group(1), m.group(2)
    if rel not in cache:
        mime = "png" if ext == "png" else "jpeg"
        with open(os.path.join(HERE, rel), "rb") as f:
            cache[rel] = ("data:image/%s;base64," % mime) + base64.b64encode(f.read()).decode()
    return cache[rel]


out = re.sub(r'(img/[a-z0-9_]+\.(jpg|png))', _inline, src)
os.makedirs(os.path.join(HERE, "build"), exist_ok=True)
dst = os.path.join(HERE, "build", "curiositys-doors.html")
with open(dst, "w", encoding="utf-8") as f:
    f.write(out)
print("baked %d images -> %s (%.2f MB)"
      % (len(cache), dst, os.path.getsize(dst) / 1024 / 1024))
