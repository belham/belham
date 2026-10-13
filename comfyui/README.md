# ComfyUI: turn a photo of a person into a Warhammer 40k Space Marine

`wh40k-astartes-face-workflow.json` takes a photo of a person and generates a
portrait of them in Space Marine / Custodes power armor. It uses:

- **FLUX.1-dev** as the base model
- the **[Adeptus Astartes [Space Marine/Custodes] FLUX LoRA](https://civitai.com/models/766534/adeptus-astartes-space-marinecustodes-flux-warhammer-40k-armor-concept)** for the armor
- **[PuLID-Flux](https://github.com/lldacing/ComfyUI_PuLID_Flux_ll)** to keep the person's face and head

```
Load Flux ─► LoRA (armor) ─► Apply PuLID-Flux ◄── your photo
                 │                  │
                 ▼                  ▼
              Prompt ──► FluxGuidance ──► KSampler ──► VAE Decode ──► Save
```

## 1. Install the PuLID-Flux custom node

ComfyUI 0.3.7 or newer. Remove or disable `ComfyUI-PuLID-Flux` (balazik) first,
since both packs register a node called `ApplyPulidFlux`.

```bash
cd ComfyUI/custom_nodes
git clone https://github.com/lldacing/ComfyUI_PuLID_Flux_ll.git
cd ComfyUI_PuLID_Flux_ll
pip install -r requirements.txt     # use ComfyUI's own python/venv
```

Or search for `ComfyUI_PuLID_Flux_ll` in ComfyUI-Manager. On Windows portable,
if `insightface` fails to build, see
[deepinsight/insightface#2576](https://github.com/deepinsight/insightface/issues/2576).

## 2. Download the models

| File | Folder | Source |
|---|---|---|
| `flux1-dev.safetensors` (~24 GB VRAM) or `flux1-dev-fp8-e4m3fn.safetensors` (~12 GB) | `models/diffusion_models/` (or `models/unet/`) | [black-forest-labs/FLUX.1-dev](https://huggingface.co/black-forest-labs/FLUX.1-dev) (gated: accept the license) / [Kijai/flux-fp8](https://huggingface.co/Kijai/flux-fp8) |
| `t5xxl_fp8_e4m3fn.safetensors`, `clip_l.safetensors` | `models/text_encoders/` (or `models/clip/`) | [comfyanonymous/flux_text_encoders](https://huggingface.co/comfyanonymous/flux_text_encoders) |
| `ae.safetensors` | `models/vae/` | [black-forest-labs/FLUX.1-schnell](https://huggingface.co/black-forest-labs/FLUX.1-schnell/blob/main/ae.safetensors) |
| the Adeptus Astartes LoRA (85.6 MB) | `models/loras/` | [direct download](https://civitai.com/api/download/models/857358?fileId=766566) ([model page](https://civitai.com/models/766534/adeptus-astartes-space-marinecustodes-flux-warhammer-40k-armor-concept)); may need a Civitai login |
| `pulid_flux_v0.9.1.safetensors` | `models/pulid/` (create it) | [guozinan/PuLID](https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors?download=true) |
| EVA02-CLIP-L-14-336, AntelopeV2, facexlib | `models/clip/`, `models/insightface/models/antelopev2/`, `models/facexlib/` | Downloaded automatically on the first run |

## 3. Load and run

1. Drag `wh40k-astartes-face-workflow.json` onto the ComfyUI canvas.
2. In each loader, pick the file you actually downloaded. The JSON uses
   placeholder names (`flux1-dev.safetensors`, `adeptus_astartes_flux.safetensors`),
   so a red node just means the file name differs.
3. Leave the trigger word **`adeptusastartes`** at the start of the prompt; it's
   what switches the LoRA's armor style on.
4. In **Upload photo of the person**, click *choose file to upload* and select
   the photo.
5. Edit the prompt (e.g. "woman" instead of "man", Ultramarines blue, Custodes
   gold, Blood Angels red) and press **Queue**.

## Tips

- **Photo:** a clear, front-facing, well-lit face with one person in the image
  works best. With several people, add a `PulidFluxOptions` node to pick which face.
- **Keep the face visible:** the prompt says "bareheaded with no helmet". If the
  LoRA still puts a helmet on, add "helmet in hand" or "close-up portrait".
- **PuLID weight** (Apply PuLID-Flux node, default 0.9): raise it to 1.0–1.2 for a
  closer likeness, lower it to 0.7–0.8 if the face looks pasted on or the armor
  gets weaker. Setting `start_at` to 0.1–0.2 gives the LoRA more control over the
  composition.
- **LoRA strength** (default 1.0): the author recommends 0.6–1.5. Higher means
  bulkier, more ornate armor; going too high can weaken the likeness. The LoRA
  mixes many armor types (Custodes, traitor, even the Emperor's), so steer it in
  the prompt: "bulky armor", "ornate", "gold trim", "fur trim", plus colors,
  armor parts, weapons and emblems.
- **Sampler:** 25 steps, Euler / simple, CFG 1.0, FluxGuidance 3.5. Flux dev
  ignores negative prompts at CFG 1, so the negative is zeroed out.
- **Low VRAM:** use the fp8 or GGUF Flux model and keep `weight_dtype` at
  `fp8_e4m3fn`.
- **License:** the LoRA is under the FLUX.1 [dev] Non-Commercial License.
  InsightFace models are non-commercial too; `PulidFluxFaceNetLoader` (after
  `pip install facenet-pytorch --no-deps`) replaces `PulidFluxInsightFaceLoader`
  if that matters, but Flux dev and the LoRA stay non-commercial.
