# funnel-site — pickhealthadvisor.com

The deployable site. `index.html` is the whole thing; the two `.webp` files are the
advisor photos. Nothing here needs a build step — drag this folder into Vercel.

**Everything in this folder becomes a public URL.** Originals and design references live
one level up in `../funnel-source/` so they don't get published — that's where the
full-size headshots and the competitor footer screenshot went. Keep it that way.

Companion: `../funnel-sites.md` is the *why*. This file is the *how to change it*.

---

## Add a Senior Benefit Advisor

Everything about an advisor lives in one place: the `ADVISORS` object near the top of
the `<script>` block. Copy a block, change the values, done — no markup to touch.

```js
brandon: {
  id: "brandon",
  name: "Brandon Perez",
  title: "Senior Benefit Advisor",
  photo: "brandon.webp",          // drop the file in this folder
  phone: "(305) 555-0134",
  email: "…@gmail.com",
  npn: "12345678",
  calendly: "https://calendly.com/…",
  reviewsSource: "Facebook",
  recommendPct: null,             // null hides the "% recommend" line
  reviewCount: null,
  reviews: []                     // empty = the whole reviews panel is hidden
}
```

Photos: square-ish, ~440px wide, saved as WebP. The two existing ones were made with
`ffmpeg -i in.jpg -vf scale=440:-1 -q:v 82 out.webp` (33 KB and 11 KB).

**Reviews rule: only real ones.** Each entry is `{ name, date, text, kind }` copied verbatim
from the actual source. An empty array is always better than an invented review — the panel
just doesn't render. `kind` is `"recommendation"` (from the Facebook reviews tab) or
`"comment"` (praise left on a page post), so nobody later mistakes one for the other.

The panel shows at most **10**, inside a fixed-height scroller, with a **Learn more on
Facebook** button pointing at `reviewsUrl`. Leo's page collects Facebook *recommendations*
(yes / no), not 1–5 stars, so the badge reads "100% recommend" — there is no star rating to
show and we don't invent one.

**An advisor with a real score but no quotes still renders.** David's panel was blank
because `recommendPct` and `reviewCount` were `null`, not because anything was broken —
the live page says 100% across 115 reviews, and with those filled in the badge and the
Learn more button appear. His quote cards stay empty for the same reason as Leo's.

### Adding the rest of Leo's reviews

Only **3 of 17** could be captured. Facebook serves the reviews tab as lazy-loaded
skeletons that never resolve for an automated browser, and there is no reviews endpoint in
the scraper. Brandon can finish this in two minutes from his own logged-in browser: open
`facebook.com/HealthByLeo/reviews`, scroll, and paste each into the `reviews` array.

## Change who gets the lead

`advisorsFor()` and `likelyMedicaid()`, right under `ADVISORS`. `advisorsFor` returns a
**list** — the thank-you screen renders one card per advisor in it. Currently:

| Situation | Goes to |
|---|---|
| Income under $15k | **Medicaid screen** |
| Income $15–32k **and** household of 3+ | **Medicaid screen** |
| Income over $50k | **Leo *and* David** — both cards, lead picks |
| Everything else | **Leo Paredes** |
| Said yes to dental/vision after Medicaid | **Leo Paredes** |
| **Page is in Spanish** | **Juan Joray, and only Juan** — every rule above is skipped |

Spanish is a separate book of business: `advisorsFor()` returns early, so a Spanish
visitor never sees Leo or David and the income split doesn't run. Handing a
Spanish-speaking lead to an English-speaking advisor is a worse outcome than any
routing rule could be worth.

Everything that dials a number follows the same split — `sitePhone()` returns Juan's
line on the Spanish page and the main line everywhere else. That covers the header
"Rather just talk" button, the call band, and the skip-the-form line. Add a new
call-to-action and read it from `sitePhone()`, never `CONFIG.phone`.

David's details never appear below the $50k line. `langs: ["es"]` on an advisor restricts
them to one language — omit the field and they show in both. In the CSV, `routedTo` /
`routedToNPN` hold every name separated by ` | `.

## Advisors with missing details

The card degrades rather than inventing anything:

| Missing | What happens |
|---|---|
| `photo` | circle of initials instead of a broken image or a stock face |
| `npn` | shows "License number available on request", and the `?` explainer is hidden — no fake number, no implied licence we can't cite |
| `calendly` | booking button is hidden; phone and email become the route |
| `reviews` but real `recommendPct` | badge and "Learn more" render, no quote cards |

## Logos

Five directions in `logos/`, hand-drawn SVG — open `logos/preview.html` to compare them on
light, on dark, and at small sizes. Each has a `-on-dark` variant for the dark footer band.

**Option 5 (wordmark only) is live** in the header, at 210px. It swaps to
`logo-5-wordmark-on-dark.svg` automatically in dark mode. The other four stay in `logos/`
in case Brandon changes his mind — swapping is one `src` in `applyTheme()`.

The Medicaid screen says "you *may* qualify", links to HealthCare.gov and the state
agency directory, and only then asks the dental/vision question. It never claims to
determine eligibility, because it can't.

## Where leads go — Supabase

`CONFIG.supabase` holds a `url` and an `anonKey`. **While they are empty nothing is
transmitted anywhere** and leads sit only in the visitor's own browser, which is useless in
production. Setup is ten minutes of clicking: **`../supabase/README.md`**, with the table
definition in `../supabase/schema.sql`.

The anon key is *meant* to be public — it ships inside this page. Safety comes from the Row
Level Security policy in `schema.sql`, which lets that key **insert a lead and nothing
else**. ⛔ Never put the `service_role` key in this file.

A local copy is always kept too, so a lead survives Supabase being down. **`/#export`**
downloads every lead captured in *the browser you're using*. Not linked from anywhere.

**If leads stop landing, open the console.** `supabasePost()` now logs the server's own
message — `[lead] supabase 400 on leads: …`. The version before this one swallowed the
reason, which is how a 404 on a wrong URL went unnoticed for a whole build. `404` on a
table name means the SQL hasn't been run; a missing-column message means `schema.sql`
needs re-running.

## Did they set the appointment?

Two separate facts, deliberately not merged:

| Status | Recorded when | Trust it? |
|---|---|---|
| `none` | never touched the booking button | — |
| `clicked` | they opened the advisor's booking page | **Not an appointment.** A lead worth chasing |
| `booked` | Calendly's popup reported the booking finished | Yes |

The booking button opens Calendly in their popup rather than a new tab, because that
popup is the only thing that can tell us the booking actually completed. Their script
(`assets.calendly.com`) loads lazily and only on the confirmation screen — nothing
third-party runs during the funnel itself. If it's blocked, the button falls back to a
plain new-tab link and we simply never learn more than `clicked`. The status is never
upgraded on a guess, and never downgraded.

The lead row is already written by then, and the public key is insert-only on purpose,
so appointments append to a separate **`lead_events`** table joined on `leadUid` — a
random id the browser generates at submit. `leads_worklist` folds it back together.

Known gap: someone who books later from Calendly's confirmation email shows as
`clicked`. That is under-reporting, which is the safe direction to be wrong in.

## Languages

Two: English and Spanish, one codebase. `TEXT.en` / `TEXT.es` hold every string, including
all four legal pages. Nothing is machine-translated at render time.

- First visit follows the browser's language; after that the choice is remembered.
- The header button switches; `applyLang()` swaps `STEPS`, `PLANS`, `LEGAL`, `UI` wholesale.
- **Tile options are `{ v, l }`** — `v` is the canonical English value stored in answers and
  written to the database, `l` is what the visitor reads. Switching language therefore never
  changes routing or the lead record. Keep it that way.
- `consentText` is stored in the language actually shown, because that is the wording the
  person agreed to.
- **Review quotes are never translated.** They stay in the language the customer wrote them
  in — translating a testimonial and presenting it as their words puts words in their mouth.

To add a string: add the key to **both** `TEXT.en.ui` and `TEXT.es.ui`, then use `t("key")`
or `t("key", { name: … })`. A missing Spanish key silently falls back to English.

## Appearance

Three-way control in the header: **auto / light / dark**, remembered per browser. Auto
follows the device and keeps following it if the device flips mid-session. The wordmark
swaps to its `-on-dark` variant automatically via `effectiveTheme()`.

### CSV schema

`LEAD_FIELDS` **is** the schema — the column order there is the column order in the
file. `../website-leads.csv` holds the header row so the CRM has something to read.
**Add new columns at the end, never in the middle.**

No health or medical column exists, because the site never asks a health question.
`consentText` stores the exact wording the person agreed to — that record is what
proves the call was allowed, so don't drop it.

---

## Before this goes live

Tracked in `../funnel-sites.md`. The ones that live in this file:

- ⛔ **`support@pickhealthadvisor.com` does not exist yet.** It is now the *only* contact
  route on the Contact page, so until the mailbox is created every support email bounces.
  Needs email hosting on the domain (Google Workspace ~$7/mo, or Zoho's free tier).
- ⛔ **Juan Joray has no NPN and no Calendly on file.** His card handles both gracefully,
  but Terms of Use says every advisor gives you their National Producer Number — so as
  written, the Spanish site does not keep that promise. Get the NPN before Spanish traffic
  runs. Both go in his `ADVISORS.juan` block.
- ✅ **`../supabase/schema.sql` has been re-run.** Done 2026-08-04. `leads` went from 29 to
  31 columns (`lead_uid` and `appointment_status` added), `lead_events` was created, and the
  `leads_worklist` view was rebuilt. Verified by posting a real row through the public anon
  key: `leads` and `lead_events` both returned **201** where they used to return 400, and a
  `select` with the same key still returns empty — RLS is insert-only as intended. The test
  rows were deleted; both tables are back to 0 rows.
- ⛔ **Consent wording** is still the drafted version. The on-page warning was removed at
  Brandon's request; the requirement to have Leo or USHA compliance approve the exact
  sentence did not go away with it.
- ⛔ **The four legal pages** are rewritten but still unreviewed by counsel or compliance.
  Their "Draft — not reviewed" banners were removed at Brandon's request, so nothing on
  screen says so any more — this line is the only remaining record.
- ⬜ Carrier wordmarks are still typographic stand-ins, not official logo files.
- ⬜ 14 of Leo's 17 Facebook reviews still missing — see "Adding the rest" above.
- ⬜ No logo chosen yet; header still renders live text.

---

## End of every vibecode session — back up, then ship

**One command does both.** Run it at the end of any session where `index.html` changed:

```bash
bash "ushamiami/Lead Generation/funnel-site/ship.sh"            # preview URL
bash "ushamiami/Lead Generation/funnel-site/ship.sh" --prod     # production
```

What it does, in order:

1. **Snapshots `index.html` into `prev-version/`** as `index-YYYY-MM-DD-HHMM.html`. If nothing
   changed since the last snapshot it skips rather than writing a duplicate.
2. **Warns** if the `5test` dev shortcut is still in the file, or if `CONFIG.supabase` is missing
   its url or key. On `--prod` a warning makes it ask before continuing.
3. **Writes `.vercelignore`** so `prev-version/`, `ship.sh`, `README.md` and `.gstack/` never get
   published, then deploys.

**`prev-version/` is the history.** There is no git in this project, so that folder is the only
record of what the site used to look like. Never delete it, never publish it. To roll back, copy
a snapshot over `index.html` and ship again.

Preview is the default on purpose: it gives you a real clickable URL without changing what the
public sees. Use `--prod` when you actually mean it.

### Vercel

Project `funnel-site` under team `tta11`, already linked via `.vercel/`. Production is
**https://funnel-site-seven.vercel.app**. The domain **pickhealthadvisor.com** is registered in
the same account but is not attached to this project yet — note it is `.com`, while every
document in this brain refers to `pickhealthadvisor.com`. **Settle which domain is the real
one before pointing traffic anywhere.**
