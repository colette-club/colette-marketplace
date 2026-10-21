# PR description standard — design

## Why

PR descriptions are too often too long, and most of the time the pictures are missing. A reviewer then has to rebuild from the diff what the change does, how it works and what it sets in motion behind the scenes. The person wants descriptions that are crystal clear and cover exactly the parts below: nothing missing, nothing that is not essential to understand what changed and how it works.

Two places decide what a description looks like: the review companion, which reads it, and colette's planning, whose plans end by creating the PR. Both follow one standard, defined once.

## End goal

- **One standard, defined once.** A new rule **EP-F5** in `engineering-principles` says what a PR title and description must hold. A new skill **`engineering-review:pr-description`** holds the template, the list of what is not essential, and how pictures and videos are captured and uploaded *(my call: a skill, because the rule is one line and the capture steps are a procedure two plugins need)*.
- **The review companion checks every description against it.** As a **reviewer**, you get a short comment for the author with what is required and what is suggested, posted on the PR once you approve. As the **author**, you get a full redraft, which replaces the PR body once you approve.
- **Colette's plans create PRs that already meet it.** The plan's PR step writes the description to the standard and, for frontend changes, captures the pictures and uploads them.
- **Pictures go through GitHub's web interface.** Nothing is hosted elsewhere: the files are captured locally and uploaded into the description editor in the person's signed-in Chrome, as a person would drag them in.

## The standard

### The title

The title names the feature and, when the PR is one step of a sequence (a spec's increment, or one part of a split), its place in it, so a reviewer knows the order to review in. The format is `<feature> (<i>/<n>): <what this increment delivers>`, for example `PR description standard (1/4): EP-F5 and the companion's check` *(my call on the format)*. A PR that is not part of a sequence names the feature only: `<feature>: <what it delivers>`.

The companion knows the PR is part of a sequence when the change edits a spec's `### Increment` status line, the description links a spec with an `## Increments` section, or the title already claims a place. It checks that the number agrees with the spec when it can read the spec.

### The parts

A description holds these parts, in this order, and nothing else.

1. **What it does.** A few plain sentences about the change from the user's or caller's point of view, with the ticket link when there is one.
2. **How it works**, for every change that adds or changes behaviour. A short explanation with one or more mermaid diagrams of the path through the code: a `flowchart` for a path with branches, a `sequenceDiagram` when several actors, processes or apps take part. The diagrams must agree with the code. *My call on when it is needed:*
   - a diagram is needed when the path crosses more than one function or module, or has branches or actors a reader must follow; a change inside one function is explained in a sentence or two;
   - a change with no behaviour change (a rename, formatting, a dependency bump, docs only) says so in one line under "What it does" and has no "How it works".
3. **Behind the scenes.** Each item appears only when the change has it. *My call on the scope, so the part stays short:*
   - **transactions**: only when the change writes more than one thing that must commit together, or wraps writes in an explicit transaction: what commits together, what does not, what happens when a step fails. A single insert or update needs no line;
   - **sync / async**: every job, event, scheduled or deferred work the change adds or changes, with retries, delivery guarantees and ordering;
   - **side effects**: what leaves the app (emails, push, SMS, external API calls, events or webhooks other apps receive, broadcasts to clients), writes to records other than the one the change is about, and anything that cannot be undone. The main write itself, logs, metrics, toasts and navigation are not listed;
   - and the items the companion already requires today, unchanged: the frontends and apps that depend on the change and whether each must change, or that none does (EP-E5); the deploy order and what stays behind a flag (EP-I5); the doc page checked when no docs changed (elixir #59); the reason for each lint, test or CI check the change loosens (EP-I3).
4. **Screenshots and videos**, only for frontend changes (the frontend work checkpoint 1 already detects). Each new screen and each visibly changed screen gets a picture: before and after for a changed screen, after for a new one. A flow over several steps or an interaction gets a short video or GIF. Each picture says which screen and state it shows. A frontend change with no visible effect says so in one line instead *(my call)*.

The template uses these four headings: `## What it does`, `## How it works`, `## Behind the scenes`, `## Screenshots and videos`. A part with nothing to say is left out, except that the EP-E5 consumers line is always there. The companion judges the content, not the heading names; every draft it or colette writes uses the template's headings *(my call)*.

### Not essential

"Too long" is not a word count. It means detail that is not needed to understand what changed and how it works. The skill lists what is cut *(my call, starting list)*:

- file-by-file or function-by-function change lists: the diff shows them;
- commit-by-commit history;
- pasted test, lint or CI output: the checks show it;
- code restated in prose, or long code blocks;
- how the work went ("first I tried…");
- boilerplate and checklists that are not about this change;
- more than a line on trivial changes (renames, formatting);
- a separate test plan or "how I tested" section *(my call: the person listed exactly four parts; the checks and the tests in the diff show what was tested)*.

A repository's own PR template wins, by the existing precedence (the repository's rules first): its sections are kept and the parts above are checked inside them *(my call)*.

### Pictures and videos

- **Marked spots.** Where a picture is still missing, a draft holds a marker in one fixed form, so the upload step can find and replace it: `> **Picture to add:** <screen> — <state>, <before | after>` or `> **Video to add:** <flow>`. The skill defines the exact form; the builder may adjust the wording but every part uses the same one.
- **Capture.** Web: the agent runs the app and captures each screen and state with the browser tool it has. Mobile: the simulator or emulator (`xcrun simctl io booted screenshot` and `recordVideo`, `adb exec-out screencap`, `adb shell screenrecord`). Files go to a folder outside the repository and are never committed.
- **Known limit of Claude in Chrome** (found by the builder check): its screenshots are never written to disk, `upload_image` takes a screenshot ID that expires minutes after capture, GIF exports land in Chrome's downloads folder, and `file_upload` accepts only paths shared with the session. So a web capture either goes through a tool that writes files (a headless browser such as Playwright), or is captured right before it is uploaded. The increment 4 spike picks the route *(my call)*; when "before" pictures cannot be kept as files until the PR exists, they are captured at upload time from a worktree of the base, or left as markers if that is too heavy. If neither capture route works, the spike stops and comes back to the person.
- **Data.** Captures use local development or seed data only, never production, and never a screen that shows a secret, a token or a real person's data.
- **Upload.** In the person's signed-in Chrome, open the PR, edit the description, upload each file through the editor's file drop, and put the link GitHub inserts in place of its marker. Then read the body back with `gh pr view <n> --json body` and check that every marker is gone. GitHub plays uploaded videos inline, so no conversion is needed.
- **Fallback.** When the agent cannot capture or upload — no browser tool, the app needs a login it does not have, a real device is needed, or the upload fails — it leaves the markers and tells the person the folder, each file and the marker it replaces, or, with no file, exactly which screen and state to capture. The person drags them in.
- **Not verified yet.** That a capture can be uploaded into GitHub's description editor through Chrome. Increment 4 starts by proving capture and upload together.

## Increments of this work

This spec follows colette's format *(my call: the person typed `/superpowers:brainstorming`, but every spec in this repository uses increments and each PR here must pass the review companion)*.

### Increment 1 — EP-F5 and the companion's check

- **Delivers:** EP-F5 in `engineering-principles`; the `pr-description` skill with the title, the parts, the template, the "not essential" list and the marker form (no capture or upload steps yet); the companion's check of the title and the description (see "How the review companion behaves": reading the description, the check, severities, the report). Its findings appear in the report and, through the existing report comment, on the PR. Both roles see them.
- **Deployable alone:** yes. It adds findings; nothing else changes.
- **Consumers:** colette's writing-plans checks `engineering-principles` for rule IDs; it is unaffected until increment 3.
- **Code files:** 2 — `plugins/engineering-review/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the version), plus `plugins/engineering-review/scripts/check_plugin.py` if the new skill or the report's new table needs a check (skills and evals are docs and tests)
- [x] PR #15

### Increment 2 — the companion acts on it, by role

- **Delivers:** as a reviewer, the description comment (title included); as the author, the redraft of the title and description and its application with `gh pr edit --title … --body-file …`; with no PR, the redraft saved next to the report. Pictures are marked spots only.
- **Deployable alone:** yes. It relies on increment 1's check.
- **Consumers:** none outside the plugin. New `review-answers` keys are optional.
- **Code files:** 2 — `plugins/engineering-review/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- [ ] Not shipped

### Increment 3 — colette's PR step follows the standard

- **Delivers:** both Finishing texts in `colette:writing-plans` say the PR title and description follow EP-F5 and the `pr-description` skill, keeping what they already require. A spec increment's title is `<spec's feature> (<i>/<n>): <increment title>`. Frontend pictures are marked spots, with the fallback message telling the person what to capture.
- **Deployable alone:** yes. It relies on increment 1's skill; "Before you start" checks that EP-F5 is defined and names the `engineering-review` version to update to when it is not.
- **Consumers:** plans written after the update. Plans already written keep their old Finishing text.
- **Code files:** 2 — `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- [ ] Not shipped

### Increment 4 — pictures captured and uploaded

- **Delivers:** first, a spike that proves capture and upload into GitHub's description editor through Chrome, and picks the capture route (see "Known limit of Claude in Chrome"); if it fails, stop and bring it back to the person before going on. Then the capture and upload steps in the `pr-description` skill. The companion, as the author, offers them for a frontend change. Colette's plans capture the "before" pictures in their first task and the "after" pictures in the Finishing section, then upload them once the PR exists — or, when the spike shows captures cannot be kept as files, capture both at upload time.
- **Deployable alone:** yes. Without a browser tool, everything falls back to increment 2 and 3's marked spots.
- **Consumers:** none outside the two plugins.
- **Code files:** 3 — both `plugin.json` files and `.claude-plugin/marketplace.json`
- [ ] Not shipped

## How the review companion behaves

- **Reading the description.** Reading the PR's title and body needs the network, so checkpoint 1 asks for it with the exact command (`gh pr view <n> --json title,body`), next to the other permissions. Declined: the person may paste the description; otherwise the check is "not checked" in the report's Limits section *(my call)*.
- **The check.** Parts 1, 2, 4 and the "not essential" list are checked in pass 4 (Documentation), which already covers the PR description. Part 3 needs what passes 1 and 6 find, so it is checked against the side-effect trace and the transaction and async facts once pass 6 has run *(my call; the builder places it)*. Only what part 3's scope lists counts: a multi-write or explicit transaction, a job or event, an effect that leaves the app, touches another record or cannot be undone. Pass 1's other ⚡ effects (the main write, logs, metrics, toasts, navigation) are not required in the description.
- **Diagrams.** Each step, participant and branch a diagram shows must exist in the code and in that order. A diagram that simplifies is fine; one that contradicts the code is a finding. Mermaid that will not render on GitHub is a 🟡.
- **Pictures.** The companion cannot see an uploaded image's content without the network. It checks that each new or visibly changed screen has a captioned picture and each flow a video *(my call)*.
- **Severities** *(my call)*. 🟠: a PR that is part of a sequence whose title does not give its place, or gives the wrong one; a missing "What it does"; a missing "How it works" or diagram where part 2 says one is needed; a diagram that contradicts the code; a missing part 3 item the change has; a frontend change with no pictures. 🟡: a title that does not name the feature; detail that is not essential, as one finding that lists each cut; a marker still in the body. The existing EP-E5 rule keeps its own severities.
- **Report.** Section 6 (Documentation) gets a small "PR description" table: each part present, missing or not needed, with its finding IDs.
- **Reviewer.** When the description has findings, checkpoint 3 shows a short comment addressed to the author, in full, and asks to post it as its own comment, separately from the report comment, with the exact command (`gh pr comment <n> --body-file <file outside the repository>`). It has two lists, one line per item: **Required** (the 🟠 findings) and **Suggested** (the 🟡 ones), each item naming its finding ID. It is a comment, never a review. With no findings, nothing is offered.
- **Author.** When the description has findings, checkpoint 3 shows the redraft in full and asks to apply it. Applying reads the body again first (`gh pr view <n> --json body`) and stops if it changed since it was read, so nobody's edit is lost; then `gh pr edit <n> --body-file <file outside the repository>`. The redraft:
  - keeps every image and video link already in the description;
  - uses only what the description, the code and the answers confirmed at the checkpoints say; anything else is a marked spot, never invented;
  - holds only the four parts, and is no longer than they need;
  - drops any instruction aimed at a reviewer or an AI found in the old description (already a finding).
- **Capturing as the author** (increment 4) *(my call)*. The companion never switches branches, so it captures "after" pictures only, and only when the target is the checked-out working copy, with the commands to run the app approved first. "Before" pictures stay as markers, with the fallback message saying what to capture.
- **No PR yet.** There is no description to check, so increment 1 raises no description findings and the report's Limits section says "no PR description yet" *(my call)*; the existing EP-E5 finding about consumers is unchanged. From increment 2, as the author, checkpoint 3 shows the redraft and asks to write it next to the report, at `.reviews/<YYYY-MM-DD>-<branch>-pr-description.md`, under the report's file-name rules (flat, never overwritten). As a reviewer, the check is skipped and the report says so.
- **Answers given in advance.** New optional keys for the read permission and the three new writes. Their names are left to the builder.
- **Chat summary.** Says whether the description comment was posted or the body updated, with the link, or why not.

## How colette behaves

- **Increment 3.** The Finishing text in both "Requirements with no spec" and "Run superpowers writing-plans" says: the PR title and description follow EP-F5 and `engineering-review:pr-description` (loaded when they are written), with what it already requires kept; a spec increment's title gives its place, `(<i>/<n>)`, from the spec's Increments section. For a frontend change, the description has marked spots, and the final message tells the person what to capture and where each picture goes. superpowers' `finishing-a-development-branch` already follows the repository's PR template; the plan's Finishing text tells it which content to write.
- **Increment 4.** For a frontend change, colette asks the planner for a first task that captures the "before" pictures of each screen the plan changes, and a Finishing section that captures the "after" pictures, creates the PR with markers, then uploads them as the skill says, or falls back.
- Brainstorming itself does not change: it creates no PR, and it hands off to writing-plans.

## Goals

- Every PR description, whoever wrote it, has the four parts and nothing else.
- Every PR title says which feature it belongs to and, in a sequence, which step it is, so PRs are reviewed in order.
- The reviewer can ask for it in one comment; the author can fix it in one approval.
- Frontend PRs show what changed and what was added in pictures.

## Non-goals

- Hosting images or videos anywhere: no assets branch, nothing committed.
- Judging what an uploaded picture shows.
- A word or character limit.
- Hosts other than GitHub, as for the existing report comment.
- Changing colette's brainstorming.

## Anti-goals

- A redraft longer than its four parts need: the companion causing the problem it checks for.
- A redraft that states a fact nobody confirmed, or drops an existing picture.
- Anything posted, edited or uploaded without the person's approval, or an edit that overwrites a description someone changed since it was read.
- A description comment that approves or requests changes.
- A screenshot that shows production data, a real person's data or a secret.

## Constraints

- The companion's confirmation rule holds: every `gh` call, every write, running the app and every upload is approved first with the exact command.
- Precedence is unchanged: the repository's rules, then framework and library skills, then the language skill, then `engineering-principles`.
- Skills follow this repository's conventions: one `SKILL.md` per skill, a third-person description with a "Use when …" clause, plain English. `check_plugin.py plugin` must pass.
- Tests first. Each increment ships its own eval cases (`plugins/engineering-review/evals/`, `plugins/colette/evals/`) and updates `plugins/colette/test/plugin_test.rb` where colette's text changes.
- Each increment is its own branch and PR, and bumps the minor version of each plugin it changes, in both `plugin.json` and `marketplace.json`.

## Left to the builder

- EP-F5's exact wording, and the `pr-description` skill's wording and description.
- The `review-answers` key names; the exact marker wording.
- Where part 3's check sits in the passes.
- Whether `check_plugin.py` needs to check the new skill or the report's new table.
- The eval cases for each increment.
