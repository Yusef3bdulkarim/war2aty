# F02 · Onboarding & Home

- **Branch:** `feature/onboarding-home` · **Milestone:** M2
- **Depends on:** F00, F01 (usage), F08 (docs stream), F09 (reminder stream) · **Feeds:** F03
- **Progress:** 0 / 11 DONE

First-run onboarding + privacy, and the Home hub with live Drift-backed streams.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F02-T01 | First-run gate | onboarding-seen flag in `app_settings`; shown once | TODO |
| 2 | F02-T02 | Onboarding pages | AR/EN, RTL/LTR; matches design | TODO |
| 3 | F02-T03 | Privacy explanation | «خصوصيتك مهمة» content; proceed action | TODO |
| 4 | F02-T04 | Home scaffold + greeting | header + greeting; design-accurate | TODO |
| 5 | F02-T05 | Scan CTA + choose-image | «صوّر ورقتك» / «اختار صورة» buttons → capture entry | TODO |
| 6 | F02-T06 | Usage indicator | reads `usage_cache` stream; «متبقي لك…» text | TODO |
| 7 | F02-T07 | Recent-documents strip | Drift stream; empty handled | TODO |
| 8 | F02-T08 | Upcoming-reminder card | Drift stream; empty handled | TODO |
| 9 | F02-T09 | Home empty state | «ابدأ بتصوير أول ورقة» | TODO |
| 10 | F02-T10 | Loading/skeleton states | shimmer while streams load | TODO |
| 11 | F02-T11 | Nav into capture | CTA routes to F03 | TODO |

## Exit DoD
Home renders live streams + usage in both locales; onboarding shown once; all empty/loading states correct.
