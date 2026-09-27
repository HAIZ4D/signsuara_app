# Tests the planned custom-gesture matcher (CLAUDE.md step 8) on the existing recordings.
# Read-only: imports C:\signsuara_ml\features.py and reads signsuara_data_v2.csv.
#
# Idea: pretend one built-in sign is a "custom gesture", enrol it from 5 random recordings,
# then replay every other recording row by row like the app does, and count:
#   hit   = held-out recordings of that sign where the custom gesture IS announced
#   false = recordings of other signs / Rest where it is WRONGLY announced
import random, sys
import numpy as np, pandas as pd

sys.path.insert(0, r"C:\signsuara_ml")
from features import WIN, DYNAMIC, add_acc, extract

N_ENROL, TRIALS, EVERY = 5, 20, 5  # 5 recordings per custom gesture, predict every 5 rows
SHIFTS = [-6, -3, 0, 3, 6]  # same as train_v2.py for moving signs
FACTORS = [1.0, 1.25, 1.5, 2.0]  # "close enough" = factor x largest distance inside enrolment

df = add_acc(pd.read_csv(r"C:\signsuara_ml\signsuara_data_v2.csv"))
recs = {rep: g.reset_index(drop=True) for rep, g in df.groupby("rep_id")}
label_of = {rep: g.label.iloc[0] for rep, g in recs.items()}


def vec(w):
    return np.array(list(extract(w).values()))


def enrol_windows(g, moving):  # exactly like train_v2.py
    if moving:
        centre = int(g.acc.rolling(5, center=True).mean().idxmax())
        starts = [min(max(centre - WIN // 2 + s, 0), len(g) - WIN) for s in SHIFTS]
    else:
        starts = [len(g) - WIN]
    return np.array([vec(g.iloc[s:s + WIN]) for s in starts])


def live_windows(g):  # what GestureClassifier sees: every 5 rows once the buffer is full
    return np.array([vec(g.iloc[end - WIN:end]) for end in range(WIN, len(g) + 1) if end % EVERY == 0])


print("Extracting features...")
enrol = {r: enrol_windows(g, label_of[r] in DYNAMIC) for r, g in recs.items()}
live = {r: live_windows(g) for r, g in recs.items()}
scale = np.vstack(list(enrol.values())).std(axis=0)  # per-feature spread over all training windows
scale[scale < 1e-9] = 1.0


def nearest(windows, bank):  # distance from each window to its nearest enrolment window
    return np.sqrt((((windows[:, None, :] - bank[None, :, :]) / scale) ** 2).sum(-1)).min(1)


def limit(enrol_reps, factor):  # largest leave-one-recording-out distance inside enrolment
    d = [nearest(enrol[r], np.vstack([enrol[o] for o in enrol_reps if o != r])).min() for r in enrol_reps]
    return factor * max(d)


def announced(m):  # m = per-prediction match; 2 matches in a row = announced (live rule)
    return bool(np.any(m[1:] & m[:-1]))


# Rule "limit":  custom wins when closer than its own limit.
# Rule "closer": ...AND closer to the custom recordings than to ANY built-in example (incl. Rest).
# Fair test: the sign playing "custom" is removed from the built-in examples (it must be new),
# and each tested recording is removed too (it must not match itself).
random.seed(0)
rows = []
for label in sorted(set(label_of.values()) - {"Rest"}):
    mine = [r for r in recs if label_of[r] == label]
    builtin = {r: nearest(live[r], np.vstack([enrol[o] for o in recs if o != r and label_of[o] != label]))
               for r in recs}
    for trial in range(TRIALS):
        chosen = random.sample(mine, N_ENROL)
        bank = np.vstack([enrol[r] for r in chosen])
        held = [r for r in mine if r not in chosen]
        others = [r for r in recs if label_of[r] != label]
        for f in FACTORS:
            t = limit(chosen, f)
            for rule in ["limit", "closer"]:
                def hit(r):
                    d = nearest(live[r], bank)
                    return announced((d < t) & ((d < builtin[r]) if rule == "closer" else True))
                rows.append({
                    "rule": rule, "custom": label, "factor": f,
                    "hit": np.mean([hit(r) for r in held]),
                    "false": np.mean([hit(r) for r in others]),
                    "false_rest": np.mean([hit(r) for r in others if label_of[r] == "Rest"]),
                })

res = pd.DataFrame(rows)
cols = ["hit", "false", "false_rest"]
pd.set_option("display.width", 120)
print(f"\n{TRIALS} random enrolments of {N_ENROL} recordings per gesture (all numbers in %).")
print("\nOverall per rule and factor:")
print((res.groupby(["rule", "factor"])[cols].mean() * 100).round(1).to_string())
print("\nPer gesture, rule 'closer':")
print((res[res.rule == "closer"].groupby(["factor", "custom"])[cols].mean() * 100).round(1).to_string())
