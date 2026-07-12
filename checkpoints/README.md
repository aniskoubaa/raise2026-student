<!-- Author: Prof. Anis Koubaa <anis.koubaa@gmail.com> -->

# Model checkpoints — how to get the Day-2 reference brain

> Trained checkpoints are **not stored in git** (the reference SmolVLA run is
> **1.3 GB**). This page tells you how to get one. The *dataset* they are
> trained on IS in the repo (`RAISE2026/datasets/`) — so anyone can reproduce
> the checkpoint exactly.

## The reference checkpoint (`smolvla_C_ref`, v2 — greenhouse scan policy)

| | |
|---|---|
| Task | C — "pick the red tomato" among green distractors, at a real plant row |
| Trained on | `RAISE2026/datasets/raiseschool__raise_ripeness_sort_ref` (in this repo — 50 SCAN episodes) |
| Recipe | SmolVLA base, 6000 steps, batch 64 — **~2 h** on an RTX 4090 laptop (16 GB) |
| Result | **100/100** on the Lab-2.2 evaluator (8/8 picks in greenhouse scenes, 0 wrong grabs, ≤201 ms/action) |
| Expected local path | `~/raise_checkpoints/smolvla_C_ref/checkpoints/006000/pretrained_model` |

The Day-2 executor **auto-detects the newest checkpoint** under
`~/raise_checkpoints/smolvla_C_ref/checkpoints/` when `VLA_LOCAL_CKPT` is unset.

## Option 1 — download from the GitHub Release (recommended: ~2 min)

The checkpoint is published as a **release asset** (687 MB tar.gz):
<https://github.com/aniskoubaa/raise_summer_school/releases/tag/day2-smolvla-ref-v2>

**In the browser** (logged in to GitHub with repo access): open the release
page, click `smolvla_C_ref_v2_greenhouse.tar.gz`, then:

```bash
mkdir -p ~/raise_checkpoints/smolvla_C_ref/checkpoints/006000
tar -xzf ~/Downloads/smolvla_C_ref_v2_greenhouse.tar.gz \
    -C ~/raise_checkpoints/smolvla_C_ref/checkpoints/006000
```

**From the terminal** — while this repo is *private*, downloads need a token
(once it's public, the plain browser URL works with `curl -L`):

```bash
mkdir -p ~/raise_checkpoints/smolvla_C_ref/checkpoints/006000
cd ~/raise_checkpoints/smolvla_C_ref/checkpoints/006000
ASSET=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/aniskoubaa/raise_summer_school/releases/tags/day2-smolvla-ref-v2 \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['assets'][0]['id'])")
curl -L -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/octet-stream" \
  -o ckpt.tar.gz "https://api.github.com/repos/aniskoubaa/raise_summer_school/releases/assets/$ASSET"
tar -xzf ckpt.tar.gz && rm ckpt.tar.gz
```

Either way the executor auto-detects the resulting path.

## Option 2 — reproduce it (~2.5 h, one command)

The training dataset is in the repo, so anyone can retrain the same thing:

```bash
finetune_d4 --task C --team ref --hf-user raiseschool --steps 6000 --launch
tail -f ~/raise_checkpoints/smolvla_C_ref.train.log     # done in ~2 h
```

## Option 3 — copy from the instructor box (LAN)

```bash
rsync -a instructor-box:~/raise_checkpoints/smolvla_C_ref ~/raise_checkpoints/
```

## Using ANY checkpoint

```bash
export VLA_LOCAL_CKPT=<path-to>/checkpoints/00XXXX/pretrained_model
vla_d4 --task C --spawn
```

Point at the `pretrained_model` folder (it holds `model.safetensors`, the
config, and the pre/post processor files the inference pipeline needs).
