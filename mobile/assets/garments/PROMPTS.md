# Garment Illustration Prompts

Generation prompts for the starter-wardrobe placeholder illustrations — one per
category. Outputs land in this folder as `<category>.png` and are tinted at
runtime with the item's colour (`BlendMode.multiply`), so the artwork **must
stay white/grayscale**: white fabric, gray fold shading, black ink lines.

## Asset spec

- **File**: `tops.png`, `outerwear.png`, `bottoms.png`, `dresses.png`,
  `shoes.png`, `bags.png`, `accessories.png` — in `mobile/assets/garments/`
- **Size**: 1024×1024 PNG
- **Palette**: strictly monochrome — white garment, gray shading, black linework
  (any colour breaks the runtime tint)
- **Background**: plain white (stripped to transparency during integration)
- **Framing**: front-facing flat lay, centered, garment fills ~80% of the frame,
  consistent visual scale across all seven
- Generate 2–3 candidates per category and keep the best — set-consistency
  beats single-image perfection.

## Shared style block

Append this to every prompt:

```text
in the style of a professional fashion vector illustration: clean black ink
linework with varying stroke weight, soft gray fabric-fold shading, white
garment on a pure white background, front-facing flat lay, centered, no text,
no watermark, no background elements, square composition with the garment
filling about 80% of the frame, monochrome, black and white only, isolated
on white
```

## Prompts

### 1. tops.png

```text
A classic short-sleeve crew-neck t-shirt with a chest pocket, natural fabric
wrinkles and drape, [shared style block]
```

### 2. outerwear.png

```text
A long-sleeve button-down overshirt / light jacket with collar, button placket
and one chest flap pocket, sleeves hanging naturally with fold creases,
[shared style block]
```

### 3. bottoms.png

```text
A pair of straight-leg jeans with waistband, belt loops, fly stitching, front
pockets and natural knee creases, [shared style block]
```

### 4. dresses.png

```text
An elegant knee-length A-line dress with thin straps, fitted bodice and
flowing skirt with drape folds, [shared style block]
```

### 5. shoes.png

```text
A low-top leather sneaker in side profile with laces, stitched sole and toe
cap, [shared style block]
```

### 6. bags.png

```text
A structured leather handbag with top handle and front flap with clasp,
[shared style block]
```

### 7. accessories.png

```text
A coiled leather belt seen from a three-quarter angle with metal buckle and
stitched edges, [shared style block]
```

## After generating

Drop the seven PNGs in this folder and say the word — integration (background
strip, pubspec asset registration, tinted rendering in `GarmentPlaceholder`
with the CustomPaint fallback, contact-sheet review across colours) is wired
from there.
