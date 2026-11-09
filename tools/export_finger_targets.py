# Prints kSignFingerTargets for lib/learn/sign_targets.dart (README.md, "Learn"): where each finger
# should be for each sign in Sign Quest = the average raw flex value (thumb, index, middle, ring,
# pinky) of all training rows of that sign. Read-only on C:\signsuara_ml\signsuara_data_v2.csv.
#
# Rows with a 4095 reading are left out (the flex ADC's top value = a loose contact, not a finger).
# Rest is left out (Sign Quest never asks for it). For each sign the comment shows how many rows and
# recordings went in, and the spread (standard deviation) of each finger, to judge the tolerance.
#
# Run:  python tools/export_finger_targets.py   then paste the output over the map in sign_targets.dart.
import sys
import pandas as pd

DATA = r"C:\signsuara_ml\signsuara_data_v2.csv"
FINGERS = ["thumb", "index", "middle", "ring", "pinky"]

df = pd.read_csv(DATA)
glitch = (df[FINGERS] == 4095).any(axis=1)
clean = df[~glitch & (df.label != "Rest")]
print(f"// {len(df)} rows read, {int(glitch.sum())} with a 4095 glitch left out.", file=sys.stderr)

print("const kSignFingerTargets = <String, List<double>>{")
for label, g in sorted(clean.groupby("label"), key=lambda item: item[0]):
    means = ", ".join(str(round(v)) for v in g[FINGERS].mean())
    spread = ", ".join(str(round(v)) for v in g[FINGERS].std(ddof=0))
    print(f"  '{label}': [{means}], // {len(g)} rows, {g.rep_id.nunique()} recordings; spread {spread}")
print("};")
