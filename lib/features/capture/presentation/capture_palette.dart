/// The capture flow's own two surfaces, from `Waraqti.dc.html` → `camera` and
/// the `camPerm` sheet.
///
/// These live here rather than in `core/theme` because nothing outside the
/// camera flow goes dark — the rest of the app is the warm off-white palette.
library;

import 'package:flutter/painting.dart';

/// The viewfinder's near-black background, `#111417`.
const Color captureBackdrop = Color(0xFF111417);

/// The dim over whatever is behind a capture sheet, `rgba(20,32,36,.5)`.
const Color captureScrim = Color(0x80142024);

/// The crop/preview screen's charcoal background, `#1B1F22`.
const Color previewBackground = Color(0xFF1B1F22);

/// The preview screen's darker action bar, `#22272B`.
const Color previewActionBar = Color(0xFF22272B);

/// The muted slate the preview hint and its icon use, `#9FB0B6`.
const Color previewHintInk = Color(0xFF9FB0B6);
