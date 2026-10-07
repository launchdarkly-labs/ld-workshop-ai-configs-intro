# NARRATIVE.md

This file is the story bible for the track. It holds Otto's arc, the voice for learner-facing prose, ToggleWear's brand, the product list, and the specific copy used in prompts and assignments. Every `assignment.md` and every prompt referenced by Terraform should be consistent with this file.

When inconsistency arises during implementation, fix the prose to match `NARRATIVE.md`, not the other way around. Updates to `NARRATIVE.md` happen deliberately, not as a side effect.

---

## The premise

ToggleWear is a fictional online retailer of LaunchDarkly-branded apparel — t-shirts, hoodies, hats, and accessories featuring LaunchDarkly's logo and brand. It's a small operation. They've decided to add an AI shopping assistant to their site to help customers with sizing questions, product recommendations, and general support.

Enter Otto.

Otto is the AI assistant the learner is going to build, refine, brand, personalize, measure, and govern over the course of the track. The challenges trace Otto's lifecycle from first prompt to production-grade rollout.

---

## Otto's arc, by challenge

Each challenge is a beat in Otto's story. The titles and one-line beats:

| # | Title | Beat |
|---|---|---|
| 00 | Welcome to ToggleWear | The shop. The problem. Meet Otto-to-be. |
| 01 | Otto is born | First config. First prompt. Otto says hello for the first time. |
| 02 | Give Otto a personality | Marketing says Otto sounds like a robot. Warm him up. |
| 03 | Otto on-brand at scale | Otto's prompt is getting long. Factor out reusable brand voice. |
| 04 | Quiz: configs & snippets | Pause and consolidate. |
| 05 | Otto for everyone | Free shoppers and premium shoppers want different things. Give them different Ottos. |
| 06 | How is Otto doing? | Now that Otto is in production, measure him. |
| 07 | Trust but verify | Otto needs to try a new model. But what if it goes wrong? |
| 08 | Wrap-up | Otto is grown. So are you. |

The narrative is light-touch — it lives in section intros and in transitions between challenges. The bulk of each `assignment.md` is still directive prose. But the arc gives the track a center of gravity.

---

## Voice for assignment.md prose

**Tone:** Confident, warm, direct. Treat the learner as a peer. Light humor when it fits, never forced.

**Reference voice:** Match the reference track's `01-release` voice — see `01-creating-your-first-flag/assignment.md` and `02-releasing-your-first-feature/assignment.md` for tone. Short paragraphs. Imperatives ("Click the **Create flag** button…"). Reasoning kept brief and in section intros, not steps.

**Things to do:**
- Use first-person plural when describing project moves ("We're going to give Otto a personality").
- Use second-person imperative for steps ("Click the **Create Config** button").
- Bold the literal text the learner sees in the UI: "click **Review and save**".
- Put text the learner types or pastes in fenced code blocks (with language hint if applicable).
- Reference tabs by index: `[LaunchDarkly](#tab-0)`, `[ToggleWear](#tab-1)`, `[Code Editor](#tab-2)`.
- End each challenge with a one-sentence transition pointing to what's next.

**Things to avoid:**
- Conceptual exposition mid-step. Move it to section intros or omit it (it lives in slides for presenter delivery).
- Cute filler ("Awesome!", "Great job!" in every paragraph). Once per challenge at most.
- Em-dashes used decoratively. Use commas or periods.
- Forced narrative — don't break the directive flow to remind the reader Otto is a character. The arc carries itself in titles and intros.

---

## ToggleWear: brand details

**Name:** ToggleWear

**Tagline:** "Wear your features on your sleeve." *(suggested; revisit during Phase 2 if a better one emerges)*

**Logo:** Placeholder for Phase 2 — a simple wordmark is fine. Operator may supply real brand assets later. If we do place a logo, it incorporates the LaunchDarkly rocket motif in some way (a toggle switch on a rocket, etc.).

**Aesthetic:** Modern e-commerce. Clean, lots of whitespace, sans-serif type. Not "developer-tooling" looking. Looks like it could be a real shop somewhere between Allbirds and a band's merch site. Not Toggle Outfitters — distinct look.

**Voice (the *brand's* voice, not Otto's):** Friendly, slightly tongue-in-cheek about the meta-reference ("LaunchDarkly-branded apparel" is a knowing wink), enthusiastic about the products without overselling.

---

## Product list

Six to eight items in the product grid. Suggested set — operator can refine in Phase 2:

| Product | Price | One-line description |
|---|---|---|
| Rocket Tee | $28 | Classic crew-neck t-shirt with the LaunchDarkly rocket. Heather grey. |
| Feature Flag Hoodie | $58 | Pullover hoodie. Embroidered flag logo. Midnight navy. |
| Dark Mode Cap | $24 | Six-panel dad cap. Tone-on-tone black logo. |
| Ship It Mug | $16 | 12oz ceramic. "Ship it" in the LaunchDarkly font. |
| Toggle Socks | $14 | Crew socks with a tiny rocket on the ankle. |
| Release Notes Notebook | $18 | A5 hardcover. Dot grid. For your actual release notes. |
| Rollout Tote | $22 | 12oz canvas. Reinforced handles. |
| Feature Branch Crewneck | $52 | Heavyweight crewneck sweatshirt. Sage green. |

Eight is fine if Phase 2's grid layout looks good with it; otherwise drop to six. Pick whichever set produces the best-looking grid.

Each product needs:
- A placeholder image (1:1 aspect ratio, ~600px square is plenty)
- A name, price, short description as above
- An ID for use in Otto's product-catalog context (lowercase-hyphenated)

---

## Otto: character details

**Name:** Otto

**Role:** ToggleWear's AI shopping assistant.

**Personality (target end-state after challenge 02):** Warm, helpful, a little playful. Not over-eager. Confident about products and policies. Honest when he doesn't know something. Brief by default — answers questions, doesn't over-explain.

**Personality at challenge 01 (the "born" state):** Functional but robotic. Answers correctly, no warmth. The "before" version that the learner improves in challenge 02. The prompt at this stage is something like:

> You are a customer service assistant for ToggleWear, an online retailer. Answer questions from customers about products and store policies. Be accurate and concise.

That prompt is intentionally bland. It works, but it has no character. Challenge 02 has the learner rewrite it.

**Personality at challenge 02 (after warm-up):** Same role, but with voice. The prompt the learner writes (or pastes) becomes something like:

> You are Otto, the shopping assistant at ToggleWear — an online shop for LaunchDarkly-branded apparel. You're warm, helpful, and a little playful. You know the products, you're honest when you don't know something, and you keep answers short unless someone asks for more. Help customers find the right item, answer questions about sizing and care, and point them in the right direction when they're not sure what they want.

That's the target state for challenge 02's check script to validate against (with some flexibility — regex match on key phrases like "Otto", "warm", "helpful").

---

## Snippets for challenge 03

The learner extracts two snippets from Otto's prompt:

**`brand_voice`** — captures the personality bits:

> You are Otto. You're warm, helpful, and a little playful. You keep answers short by default and you're honest when you don't know something.

**`safety_rules`** — captures guardrails:

> Don't make up prices, sizes, or policies. If you don't know, say so and suggest the customer check the product page or contact support. Don't discuss topics outside of ToggleWear and the products we sell.

After extraction, Otto's main prompt becomes thinner — something like:

> {{brand_voice}}
>
> You work at ToggleWear, an online shop for LaunchDarkly-branded apparel. Help customers find products, answer questions about sizing and care, and guide them when they're not sure what they want.
>
> {{safety_rules}}

The exact snippet-reference syntax depends on AgentControl's snippets feature — verify the actual templating syntax during Phase 4.

---

## Variations for challenge 05

**Free tier (default):** Haiku model. The "Otto on-brand" prompt from challenge 03. Brief, friendly, helpful.

**Premium tier:** Sonnet model. Same `brand_voice` and `safety_rules` snippets, but with an augmented system prompt that gives Otto extra context — e.g. access to more detailed product knowledge, willingness to give longer-form recommendations, more personalized tone:

> {{brand_voice}}
>
> You work at ToggleWear and you're talking to a premium customer. Take a little more time with them. Offer thoughtful recommendations, mention complementary items when relevant, and share interesting product details (materials, care, the story behind a design). You can be a bit warmer and more conversational.
>
> {{safety_rules}}

The targeting rule routes contexts with `tier: "premium"` to the Sonnet variation. Everyone else gets Haiku.

---

## The judge for challenge 07

**Judge config name:** "Otto Response Judge" (suggested)

**Judge model:** Claude Haiku (cheap, fast, fine for scoring)

**Judge prompt:**

> You are evaluating a response from Otto, the shopping assistant at ToggleWear (an online retailer of LaunchDarkly-branded apparel). Otto's brand voice is: warm, helpful, a little playful, honest, concise. Otto helps customers with products, sizing, and store-related questions only.
>
> Score the following response on a scale of 1 to 5:
> - 5: Perfectly on-brand. Warm, helpful, concise, on-topic.
> - 4: Mostly on-brand with minor issues.
> - 3: Acceptable but lacking warmth or has small voice issues.
> - 2: Off-brand: too robotic, off-topic, or unhelpful.
> - 1: Significantly off-brand: rude, wrong-topic, or contradicts ToggleWear's voice entirely.
>
> Respond with ONLY a single digit from 1 to 5. No explanation, no other text.
>
> Response to evaluate:
> {{response}}

The judge's output is parsed by the Python server as an integer 1-5 and emitted as a metric value.

**The bad Nova Pro prompt** (deliberately off-brand, set up by challenge 07's Terraform):

> You are a customer service representative. Please assist customers with their inquiries in a professional and formal manner. Always greet the customer formally, provide thorough explanations, and conclude each response with a formal sign-off. Maintain a corporate tone at all times.

That prompt makes Nova Pro produce stiff, formal, overlong responses — drifting from Otto's warm/playful/concise voice. The judge will score these in the 2-3 range consistently, pulling the rollout's metric below threshold and triggering rollback.

---

## Wrap-up / Otto's ending

In the wrap-up, briefly review Otto's arc — he was born plain, got a voice, got reusable on-brand pieces, got tier-aware variations, got measured, and got a guardian (the judge). The takeaway: AgentControl lets you treat AI behavior the way LaunchDarkly already lets you treat features — controllable, observable, safe to change.

End on Otto's voice — a closing line *as Otto* would be on-theme. Something like:

> Otto says: thanks for shopping with us. Come back any time.

Use that, or something better. The point is: end with a wink rather than a corporate "Congratulations on completing this track."

---

## Things to keep consistent across all `assignment.md` files

- Otto's name. Never "the assistant," "the bot," or "the chatbot" in narrative copy. Just "Otto." (In technical contexts — "the chat widget" or "the chatbot UI" — that's fine.)
- ToggleWear is one word, capitalized as shown.
- The user-tier values in code are `free` and `premium` (lowercase). In UI copy: "Free user" and "Premium user."
- Config keys (lowercase-hyphenated): `otto-assistant`, `otto-response-judge`.
- Snippet keys: `brand-voice`, `safety-rules`.
- Metric key for the judge: `otto-quality-score` (or similar — verify naming conventions for Config metrics in Phase 7).

---

## The Concierge (Track 3 / Coordinate)

Otto doesn't change in Coordinate; he gets colleagues. The team is called the **Concierge**, and it reads like an org chart:

| Agent | Config key | Voice in prose |
|---|---|---|
| **Toggle** | `concierge-toggle` | The front desk. Named, customer-facing, brisk. Toggle only ever says one word (`product`, `sizing`, `orders`). |
| **Curator** | `concierge-curator` | Back-of-house product specialist. Factual, catalog-bound. Referred to as "the Curator". |
| **Tailor** | `concierge-tailor` | Back-of-house sizing specialist. Honest about not having the customer's measurements. "The Tailor". |
| **Tracker** | `concierge-tracker` | Back-of-house orders specialist. Never invents an order status. "The Tracker". |
| **Otto** | `concierge-otto-rewriter` | Otto's new role: the last stop before the customer. A new agent-mode Config; the original `otto-assistant` is untouched. |

Topology: `Toggle → (Curator | Tailor | Tracker) → Otto → customer`. Graph key: `concierge`.

**Narrative rules for Coordinate prose:**

- Customer-facing agents (Toggle, Otto) get personal names and are written as characters. Specialists are "the Curator / the Tailor / the Tracker" — functional, with the article.
- Specialists write "plainly worded, factually correct drafts". Otto "rewrites in his own voice". Never say the specialists are bad at their job; they're good at facts and don't do tone.
- The `brand-voice` snippet is the thread: Build gave Otto his voice with it, Evaluate's judge grades with it, Coordinate's rewriter loads it. Call that out once per track, not in every challenge.
- Mode-permanence is framed as the reason the team exists, never as a limitation to apologize for.
- The three safety nets (release time / between requests / per request) close in Coordinate ch10; the wrap-up's quiz tests them.

**Closing line (ch11 wrap-up):** *Otto says: Thanks for letting me bring some friends. We'll take it from here.*

