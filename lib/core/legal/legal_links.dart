/// Where the app's published policy pages and support address live (F27-T20).
///
/// One place, because four surfaces need the same three values and must not
/// drift: the settings screen's rows, the privacy screen's footer, the pages
/// themselves (`legal/`, published to the `gh-pages` branch) and the Play
/// listing T21 fills in. `legal_links_test` asserts the URLs point at files
/// that actually exist in `legal/`, so a renamed page cannot leave a dead link
/// shipped inside the app.
///
/// Deliberately plain constants with no Flutter import: the domain layer reads
/// them too (CLAUDE.md §B1).
library;

/// The site these pages are served from — GitHub Pages, from the `gh-pages`
/// branch of the public repository (Q17).
const String legalSiteBase = 'https://yusef3bdulkarim.github.io/war2aty';

/// «سياسة الخصوصية» in full. This is the URL both stores take as *the*
/// privacy-policy link (F27-B4).
const String privacyPolicyUrl = '$legalSiteBase/privacy.html';

/// «شروط الاستخدام», carrying the "not legal/medical/financial advice"
/// disclaimer (F27-M5).
const String termsOfUseUrl = '$legalSiteBase/terms.html';

/// The published support address (Q17). Deliberately not the owner's personal
/// mailbox: this one appears on a public page and in a store listing.
const String supportEmailAddress = 'war2aty.support@gmail.com';

/// One of the three places the app can send the user outside itself.
///
/// An enum rather than three use cases, because the only thing that differs is
/// the destination — and because a closed set is what lets
/// `OpenLegalLink` be the single audited exit from the app.
enum LegalLink {
  /// The full privacy policy page.
  privacyPolicy,

  /// The terms of use page.
  termsOfUse,

  /// A pre-addressed email to support.
  support;

  /// The destination, ready to hand to the platform.
  Uri get uri => switch (this) {
    LegalLink.privacyPolicy => Uri.parse(privacyPolicyUrl),
    LegalLink.termsOfUse => Uri.parse(termsOfUseUrl),
    // `Uri(scheme:, path:)` rather than `Uri.parse('mailto:…')`: parse treats
    // the address as an opaque path and gets it right by luck, while this
    // states the shape. No subject or body — a prefilled Arabic subject
    // arrives percent-encoded in some mail clients and reads as noise.
    LegalLink.support => Uri(scheme: 'mailto', path: supportEmailAddress),
  };
}
