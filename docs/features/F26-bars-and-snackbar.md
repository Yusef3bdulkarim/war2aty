# F26 · Unified top bars, floating SnackBar, quota hint on every exit

- **Branch:** `feature/ui-polish-bars-snackbar`, based on `develop` · **Milestone:** post-F25
- **Depends on:** F21/F23 (`TealTopBar`), F07 (the remaining-analyses hint)
- **Progress:** 3 / 5 DONE

Three pieces of polish the owner asked for on 2026-10-04, after an audit of
every screen's top bar, every SnackBar call site, and every way out of the
analysis result screen.

## Locked decisions

Resolved with the owner on 2026-10-04.

1. **One top bar.** The reminder details, reminder form (create and manual)
   and privacy-policy screens drop their hand-made white bar for the result
   page's `TealTopBar`, and so does the extracted-text page reached from a
   failed analysis — the same white bar, found during T02. The image
   preview's dark crop toolbar (close + rotate) is a camera-style editor, not
   a back bar, and stays. The reminders list stays as it is: it is a bottom-nav
   tab, and like Home, Documents and Settings it has a page heading rather
   than a back bar.
2. **The title sits inside the teal bar (Option A).** `TealTopBar` takes an
   optional `title`, drawn white and centred, announced as the page heading.
   The result page and the failure screens keep passing no title.
3. **The SnackBar floats.** Set once in the theme: floating, 16px from the
   sides and the bottom, `AppRadii.md` corners. Every call site inherits it;
   none of them is edited.
4. **The remaining-analyses hint is stored however the result page is
   left**: the back arrow, the system back, «صوّر ورقة تانية» / «اختار من
   المعرض», and the reminder flow that ends on the reminders tab or Home.
   It is stored when the result route leaves the tree, not by each exit.
5. **Never over the camera.** The shell shows the hint only while it is the
   top route; otherwise it holds it and shows it once the user is back on a
   tab page.
6. **iOS swipe-back stays disabled** on the result page (`PopScope(canPop:
   false)`), unchanged.
7. **Failed analyses keep today's behaviour**: leaving one shows the hint
   if part of today's quota was used and some remains.

## Tasks

| # | ID | Task | Output | Status |
|---|---|---|---|---|
| 1 | F26-T01 | Title in `TealTopBar` | optional white centred `title`, a header for screen readers; tests | DONE |
| 2 | F26-T02 | Migrate the old bars | reminder details, reminder form, privacy policy — and the extracted-text page, a fourth copy found while migrating — on `TealTopBar`; the four `_TopBar` copies deleted | DONE |
| 3 | F26-T03 | Floating SnackBar | `snackBarTheme` in `AppTheme` (light + high contrast): floating, 16px inset, `AppRadii.md`, ink card with white Cairo text; theme + layout tests | DONE |
| 4 | F26-T04 | Hint on every exit | result route stores the hint when it leaves the tree; the shell holds it while covered; reproducing tests | TODO |
| 5 | F26-T05 | Quality gate + review | `dart format` / `flutter analyze` / `flutter test`; independent `@code-reviewer` pass | TODO |

## Exit DoD

- No screen outside the bottom-nav tabs draws its own back bar.
- Every SnackBar in the app floats with rounded corners.
- Leaving a finished analysis by any exit shows the remaining count once,
  on a tab page, never over the camera.
