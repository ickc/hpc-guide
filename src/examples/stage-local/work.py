"""Square the number in each input file, writing one output file per input file."""

import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
for f in sorted(src.glob("*.txt")):
    (dst / f.name).write_text(f"{int(f.read_text()) ** 2}\n")
