---
name: gitmoji
description: Apply the gitmoji convention to a requested commit message or Git commit. Use only when explicitly invoked.
disable-model-invocation: true
---

# gitmoji

Apply the gitmoji convention without broadening the requested action. If the user asks only for a commit message, do not stage or commit changes. If the user asks to create a commit, include only the relevant changes.

## Commit message rules

- Choose exactly one best-matching gitmoji per commit from the reference below.
- Use sentence case for the subject.
- Capitalize the first word after the emoji.
- Write the subject in imperative mood.
- Do not add a trailing period.
- Use at most five words for the subject, excluding the emoji.
- Use only: `<emoji> <Subject in imperative mood>`.
- Do not include a scope or any text between the emoji and subject.
- When creating commits, split the changes into multiple atomic commits when necessary, such as when many changes cover independent concerns. Otherwise, create one commit.
- If a repository requires an incompatible commit format, do not commit; explain the conflict first.

## gitmoji reference

- 🎨 Improve structure / format of the code.
- ⚡️ Improve performance.
- 🔥 Remove code or files.
- 🐛 Fix a bug.
- 🚑️ Critical hotfix.
- ✨ Introduce new features.
- 📝 Add or update documentation.
- 🚀 Deploy stuff.
- 💄 Add or update the UI and style files.
- 🎉 Begin a project.
- ✅ Add, update, or pass tests.
- 🔒️ Fix security or privacy issues.
- 🔐 Add or update secrets.
- 🔖 Release / Version tags.
- 🚨 Fix compiler / linter warnings.
- 🚧 Work in progress.
- 💚 Fix CI Build.
- ⬇️ Downgrade dependencies.
- ⬆️ Upgrade dependencies.
- 📌 Pin dependencies to specific versions.
- 👷 Add or update CI build system.
- 📈 Add or update analytics or track code.
- ♻️ Refactor code.
- ➕ Add a dependency.
- ➖ Remove a dependency.
- 🔧 Add or update configuration files.
- 🔨 Add or update development scripts.
- 🌐 Internationalization and localization.
- ✏️ Fix typos.
- 💩 Write bad code that needs to be improved.
- ⏪️ Revert changes.
- 🔀 Merge branches.
- 📦️ Add or update compiled files or packages.
- 👽️ Update code due to external API changes.
- 🚚 Move or rename resources (e.g.: files, paths, routes).
- 📄 Add or update license.
- 💥 Introduce breaking changes.
- 🍱 Add or update assets.
- ♿️ Improve accessibility.
- 💡 Add or update comments in source code.
- 🍻 Write code drunkenly.
- 💬 Add or update text and literals.
- 🗃️ Perform database related changes.
- 🔊 Add or update logs.
- 🔇 Remove logs.
- 👥 Add or update contributor(s).
- 🚸 Improve user experience / usability.
- 🏗️ Make architectural changes.
- 📱 Work on responsive design.
- 🤡 Mock things.
- 🥚 Add or update an easter egg.
- 🙈 Add or update a .gitignore file.
- 📸 Add or update snapshots.
- ⚗️ Perform experiments.
- 🔍️ Improve SEO.
- 🏷️ Add or update types.
- 🌱 Add or update seed files.
- 🚩 Add, update, or remove feature flags.
- 🥅 Catch errors.
- 💫 Add or update animations and transitions.
- 🗑️ Deprecate code that needs to be cleaned up.
- 🛂 Work on code related to authorization and permissions.
- 🩹 Simple fix for a non-critical issue.
- 🧐 Data exploration/inspection.
- ⚰️ Remove dead code.
- 🧪 Add a failing test.
- 👔 Add or update business logic.
- 🩺 Add or update healthcheck.
- 🧱 Infrastructure related changes.
- 🧑‍💻 Improve developer experience.
- 💸 Add sponsorships or money related infrastructure.
- 🧵 Add or update code related to multithreading.
- 🦺 Add or update code related to validation.
- ✈️ Improve offline support.
- 🦖 Code that adds backwards compatibility.
