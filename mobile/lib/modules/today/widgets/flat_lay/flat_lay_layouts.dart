/// The outfit picture's layouts: for 1 to 10 pieces, three variants each.
///
/// A variant is a list of slots, each a straight (untilted) rectangle in
/// fractions of the picture (`x`, `y`, `w`, `h` — 0–1, so it works at any
/// size and roughly any aspect; authored for a picture a little wider than
/// tall). Slots are listed **largest first**: the planner hands the
/// pieces to them in dress-priority order, so the biggest piece gets the
/// biggest slot. Slots of the same size form a group; tied pieces (a top
/// and trousers, both 600) prefer a variant whose equal slots line up with
/// them. Later slots are drawn on top, so small pieces overlap big ones
/// (shoes over the trousers), as in a real flat-lay.
///
/// To add a variant, append to the list for its count — nothing else
/// changes. Keep the slots in non-increasing area order (a test checks).
library;

/// One place a piece can go.
class FlatLaySlot {
  const FlatLaySlot(this.x, this.y, this.w, this.h);

  /// Top-left corner and size, as fractions of the picture.
  final double x, y, w, h;

  double get area => w * h;
}

typedef FlatLayVariant = List<FlatLaySlot>;

// Shorthand for the tables below.
typedef _S = FlatLaySlot;

/// `flatLayVariants[n]` = the variants for n pieces (n = 1–10).
const Map<int, List<FlatLayVariant>> flatLayVariants = {
  1: [
    [_S(.12, .06, .76, .88)],
    [_S(.16, .08, .68, .84)],
    [_S(.1, .1, .8, .8)],
  ],
  2: [
    // Side by side, equal (a top and its trousers).
    [_S(.04, .12, .45, .76), _S(.51, .12, .45, .76)],
    // A diagonal pair, equal.
    [_S(.04, .04, .5, .56), _S(.46, .4, .5, .56)],
    // A hero and a smaller piece.
    [_S(.04, .06, .58, .88), _S(.62, .42, .34, .5)],
  ],
  3: [
    // Big across the top, an equal pair under it (coat over top + bottom).
    [_S(.18, .02, .64, .46), _S(.05, .5, .42, .48), _S(.53, .5, .42, .48)],
    // An equal pair, then a smaller piece (top + bottom, then shoes).
    [_S(.03, .06, .4, .74), _S(.4, .1, .4, .74), _S(.7, .56, .28, .4)],
    // Big, medium, small (a dress, shoes, a bag).
    [_S(.03, .05, .54, .9), _S(.58, .05, .38, .48), _S(.62, .58, .3, .38)],
  ],
  4: [
    [
      _S(.03, .03, .6, .45),
      _S(.05, .5, .42, .47),
      _S(.48, .5, .42, .47),
      _S(.67, .06, .3, .38),
    ],
    [
      _S(.03, .08, .38, .62),
      _S(.38, .12, .38, .62),
      _S(.66, .55, .3, .4),
      _S(.77, .1, .18, .26),
    ],
    [
      _S(.03, .05, .5, .9),
      _S(.53, .04, .42, .46),
      _S(.55, .56, .3, .38),
      _S(.84, .62, .13, .22),
    ],
  ],
  5: [
    // The reference flat-lay: coat across the top, sweater + trousers
    // under it, shoes overlapping on the right, a watch at the edge.
    [
      _S(.2, .02, .58, .42),
      _S(.03, .46, .34, .5),
      _S(.37, .46, .34, .5),
      _S(.66, .42, .25, .48),
      _S(.87, .5, .12, .22),
    ],
    [
      _S(.03, .04, .4, .48),
      _S(.05, .5, .4, .48),
      _S(.46, .08, .3, .4),
      _S(.47, .53, .3, .4),
      _S(.8, .34, .17, .26),
    ],
    [
      _S(.03, .04, .52, .6),
      _S(.56, .04, .4, .45),
      _S(.1, .66, .32, .32),
      _S(.5, .68, .16, .24),
      _S(.72, .66, .16, .24),
    ],
  ],
  6: [
    [
      _S(.21, .02, .56, .38),
      _S(.03, .42, .3, .52),
      _S(.34, .42, .3, .52),
      _S(.66, .44, .26, .4),
      _S(.82, .04, .15, .2),
      _S(.03, .04, .15, .2),
    ],
    [
      _S(.03, .04, .36, .46),
      _S(.03, .52, .36, .46),
      _S(.42, .06, .28, .4),
      _S(.42, .52, .28, .4),
      _S(.74, .12, .2, .3),
      _S(.74, .56, .2, .3),
    ],
    [
      _S(.03, .03, .5, .56),
      _S(.55, .03, .4, .42),
      _S(.04, .62, .28, .35),
      _S(.33, .62, .28, .35),
      _S(.64, .55, .16, .22),
      _S(.8, .7, .16, .22),
    ],
  ],
  7: [
    [
      _S(.22, .02, .5, .36),
      _S(.03, .4, .28, .5),
      _S(.31, .4, .28, .5),
      _S(.6, .42, .22, .36),
      _S(.02, .02, .22, .36),
      _S(.78, .06, .18, .2),
      _S(.82, .6, .18, .2),
    ],
    [
      _S(.02, .04, .3, .44),
      _S(.35, .04, .3, .44),
      _S(.68, .04, .3, .44),
      _S(.05, .52, .25, .4),
      _S(.35, .52, .25, .4),
      _S(.66, .55, .15, .2),
      _S(.82, .7, .15, .2),
    ],
    [
      _S(.03, .03, .46, .55),
      _S(.52, .03, .42, .4),
      _S(.04, .62, .26, .35),
      _S(.32, .62, .26, .35),
      _S(.6, .48, .14, .2),
      _S(.78, .5, .14, .2),
      _S(.68, .74, .14, .2),
    ],
  ],
  8: [
    [
      _S(.22, .02, .5, .36),
      _S(.03, .4, .28, .5),
      _S(.31, .4, .28, .5),
      _S(.6, .42, .22, .36),
      _S(.02, .02, .22, .36),
      _S(.8, .06, .15, .2),
      _S(.84, .4, .15, .2),
      _S(.84, .72, .15, .2),
    ],
    [
      _S(.02, .04, .23, .42),
      _S(.26, .04, .23, .42),
      _S(.5, .04, .23, .42),
      _S(.74, .04, .23, .42),
      _S(.04, .52, .2, .4),
      _S(.28, .52, .2, .4),
      _S(.54, .56, .18, .22),
      _S(.76, .6, .18, .22),
    ],
    [
      _S(.03, .03, .44, .5),
      _S(.5, .03, .23, .45),
      _S(.75, .03, .23, .45),
      _S(.04, .58, .22, .38),
      _S(.28, .58, .22, .38),
      _S(.52, .58, .22, .38),
      _S(.77, .56, .17, .19),
      _S(.79, .78, .17, .19),
    ],
  ],
  9: [
    // Three rows, shrinking down the picture.
    [
      _S(.02, .03, .31, .36),
      _S(.35, .03, .31, .36),
      _S(.68, .03, .31, .36),
      _S(.04, .42, .27, .3),
      _S(.37, .42, .27, .3),
      _S(.7, .42, .27, .3),
      _S(.06, .75, .22, .22),
      _S(.39, .75, .22, .22),
      _S(.72, .75, .22, .22),
    ],
    [
      _S(.22, .02, .48, .34),
      _S(.03, .4, .27, .48),
      _S(.31, .4, .27, .48),
      _S(.6, .42, .22, .34),
      _S(.0, .02, .22, .34),
      _S(.78, .04, .15, .18),
      _S(.8, .24, .15, .18),
      _S(.84, .78, .15, .18),
      _S(.62, .8, .15, .18),
    ],
    [
      _S(.03, .03, .44, .48),
      _S(.5, .03, .3, .42),
      _S(.04, .56, .22, .38),
      _S(.28, .56, .22, .38),
      _S(.52, .56, .22, .38),
      _S(.82, .04, .15, .18),
      _S(.82, .26, .15, .18),
      _S(.79, .56, .15, .18),
      _S(.8, .78, .15, .18),
    ],
  ],
  10: [
    [
      _S(.02, .03, .23, .4),
      _S(.26, .03, .23, .4),
      _S(.5, .03, .23, .4),
      _S(.74, .03, .23, .4),
      _S(.04, .48, .24, .3),
      _S(.3, .48, .24, .3),
      _S(.56, .48, .24, .3),
      _S(.82, .48, .16, .2),
      _S(.1, .8, .16, .2),
      _S(.4, .8, .16, .2),
    ],
    [
      _S(.22, .02, .46, .32),
      _S(.03, .38, .26, .42),
      _S(.3, .38, .26, .42),
      _S(.58, .38, .2, .32),
      _S(.0, .02, .2, .32),
      _S(.78, .38, .2, .32),
      _S(.72, .04, .14, .16),
      _S(.85, .16, .14, .16),
      _S(.62, .78, .14, .16),
      _S(.82, .78, .14, .16),
    ],
    [
      _S(.03, .03, .42, .46),
      _S(.48, .03, .24, .44),
      _S(.74, .03, .24, .44),
      _S(.04, .54, .24, .42),
      _S(.3, .54, .24, .42),
      _S(.56, .53, .13, .18),
      _S(.7, .53, .13, .18),
      _S(.84, .53, .13, .18),
      _S(.6, .77, .13, .18),
      _S(.76, .77, .13, .18),
    ],
  ],
};

/// The most pieces a picture shows; past this the lowest-priority ones are
/// left out.
const int flatLayMaxPieces = 10;

/// The surfaces a picture is laid on (`assets/outfit_backgrounds/`) — all
/// cloth, stone or paper; hard wood read badly under folded clothes.
const List<String> flatLayBackgrounds = [
  'assets/outfit_backgrounds/bg_01_linen_oatmeal.webp',
  'assets/outfit_backgrounds/bg_02_linen_cream.webp',
  'assets/outfit_backgrounds/bg_03_linen_greige.webp',
  'assets/outfit_backgrounds/bg_04_canvas_raw.webp',
  'assets/outfit_backgrounds/bg_05_muslin_sand.webp',
  'assets/outfit_backgrounds/bg_06_plaster_warm.webp',
  'assets/outfit_backgrounds/bg_07_travertine.webp',
  'assets/outfit_backgrounds/bg_08_marble_white.webp',
  'assets/outfit_backgrounds/bg_09_paper_sand.webp',
  'assets/outfit_backgrounds/bg_10_concrete_pale.webp',
];
