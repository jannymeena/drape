# How we build Flutter apps

The conventions this app follows. When a shared widget exists for something,
use it instead of building the thing again.

---

## Shared widgets

### `AppBottomSheet` — the standard modal

`lib/shared/widgets/app_bottom_sheet.dart` · tests: `test/app_bottom_sheet_test.dart`

Every bottom-sheet modal uses it. It owns the shell, so all sheets look and
behave the same; a screen only supplies its content.

```
┌──────────────── ━━━━ ────────────────┐  grabber (always)
│            title                     │  fixed — optional
│ ┌──────────────────────────────────┐ │
│ │ child                            │ │  scrolls
│ └──────────────────────────────────┘ │
│ actions                              │  fixed footer — optional
└──────────────────────────────────────┘
```

| Parameter | What it is | Default |
|---|---|---|
| `child` | The content; scrolls | required |
| `title` | **Text only** — styling is fixed (see below) | none (no title row) |
| `actions` | Fixed footer: buttons, fine print | none (no footer) |
| `heightFactor` | Share of the screen height | `0.8` |
| `contentPadding` | Padding around `child` | `20, 0, 20, 16` |
| `scrollController` | Controller for the content's scroll view | none |

**Open** with `AppBottomSheet.show<T>(context, builder: …)`. It applies the
standard scrim and modal settings, and takes `isDismissible` and `enableDrag`.
**Return a value** with `Navigator.of(context).pop(result)`. Dismissing gives
`null`.

```dart
final result = await AppBottomSheet.show<String>(
  context,
  builder: (context) => AppBottomSheet(
    title: 'Choose a size',
    actions: FilledButton(
      onPressed: () => Navigator.of(context).pop('saved'),
      child: const Text('Save'),
    ),
    child: Column(children: [/* … */]),
  ),
);
```

**Built in — don't rebuild these per sheet:**
- **Grabber:** the `━━━━` line at the top, always shown.
- **Size and shape:** 80% of the screen tall, ivory, rounded top (20).
- **Title:** the text is the only input. It is always centred, on one line
  with an ellipsis, in `AppTypography.screenTitle` (Newsreader 24, semibold,
  espresso), the same as the pushed screens' headers.
- **No close button:** the sheet is dismissed by dragging it down or tapping
  the scrim.
- **Keyboard:** the sheet lifts above it, and tapping blank space in the
  content dismisses it.
- **Footer:** `actions` sits on the ivory bar, with the home-indicator inset
  added below.
- **Content isn't lazy:** every section is built up front, so
  `Scrollable.ensureVisible` can scroll any section into view. Plan a day uses
  this to bring the next question up once one is answered.

**Rules**
- New sheets use `AppBottomSheet.show` + `AppBottomSheet`. Don't call
  `showModalBottomSheet` directly, and don't hand-build a grabber, title row
  or footer bar.
- Put a sheet's own heading content (e.g. Plan a day's date + weather) in
  `child`. `title` is only for a plain text title.
- Long lists of hundreds of rows belong on a screen, not in a sheet (the
  content isn't lazy).

**Uses it:** Plan a day (`modules/today/widgets/plan_day_sheet.dart`), Mix &
match (`modules/today/widgets/mix_match_sheet.dart` — its Reset lives on the
grid's helper line, since the title row is text-only), Change it
(`modules/today/widgets/change_outfit_sheet.dart`). Mix & match and Change it
use `heightFactor: 0.6`.
**Not yet migrated:** Shop the look, product options, privacy,
skip confirmation, cancellation reason, settings sheets, and the wardrobe
pickers and scanner sheets.
