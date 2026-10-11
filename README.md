# Tracer Intelligence

A native iPhone app (SwiftUI, iOS 18+) for running accreditation tracers inside healthcare
facilities: manage trace topics, run independent sessions, record staff answers verbatim,
analyse them against the HHC Integrated Cluster Care Standards, follow the trace across
departments, decide risk with the SAFER matrix, and export the filled **Mock Tracer Form** as PDF.

## Repository layout

| Path | What it is |
| --- | --- |
| `Tracer/project.yml` | XcodeGen project definition (generates `Tracer.xcodeproj`) |
| `Tracer/Tracer/` | App source: `App`, `Design`, `Model`, `Services`, `Features/*` |
| `Tracer/Tracer/Resources/Data/standards.json` | 1,116 standards parsed from the HHC manual (offline library) |
| `Tracer/tools/parse_standards.py` | Re-generates `standards.json` from the manual's text (`pdftotext -layout`) |
| `supabase/functions/analyze/` | Edge function that performs answer analysis and topic drafting |
| `.github/workflows/ios-build.yml` | macOS CI job that builds an **unsigned IPA** |

## Getting the app on an iPhone (unsigned)

1. Open the repository's **Actions** tab → latest *iOS build (unsigned IPA)* run → download the
   `Tracer-unsigned-ipa` artifact and unzip it to get `Tracer-unsigned.ipa`.
2. Sign & install it with a sideloading tool using your own Apple ID, for example
   **Sideloadly**, **AltStore** or **SideStore** (free Apple IDs need re-signing every 7 days),
   or install directly with **TrollStore** on supported iOS versions.

To build locally on a Mac: `brew install xcodegen && cd Tracer && xcodegen generate && open Tracer.xcodeproj`.

## Backend

* Supabase project `tracer-intelligence` (`ljdyrdgfscjeiaohbitc`, ap-south-1).
* The `analyze` edge function calls the language model. The provider key is **not** in the app:
  it is stored in Supabase Vault (`groq_api_key`) and read server-side through
  `public.service_secret()`, which only the service role can execute. Setting an Edge Function
  secret named `GROQ_API_KEY` overrides the Vault value.
* The app only embeds the public anon key.

## Data & privacy

All topics, sessions, answers, evidence and the audit log are stored on the device (SwiftData).
Only the question, the verbatim answer, earlier answers in the same session and the selected
standard clauses are sent for analysis. Patient record numbers, photos and files are never sent.
