// Crimson Dark: let Firefox load chrome/userChrome.css and chrome/userContent.css.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Ask sites and Firefox pages for their dark variant.
user_pref("layout.css.prefers-color-scheme.content-override", 0);
