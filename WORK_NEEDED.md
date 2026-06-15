<!--
 Part of Moonrelay, a matrix protocol client.
 Copyright (C) 2025 Surena Karimpour Ghannadi

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as
 published by the Free Software Foundation, either version 3 of the
 License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# Current work

Expected timeline: ~~Mid 2026 (This will eventually become a lesson in wishful thinking)~~ lmao, it sure did

## Chat events v1
- Chat timeline needs rework.
- Text Messages **[DONE]**
- Images **[DONE]**
  - Still needs some work — dedicated image view screen needed
- Audio **[DONE]**
  - No in-app player yet
- Video **[NOT STARTED]**
- Files **[DONE]**
  - Widget needs polish

## Chat events v2
- Dynamically built text with inline images
- Code blocks support
- Right-click context menu
- Replies **[IN PROGRESS]**
- Threads **[INVESTIGATION NEEDED]**
- Stickers **[INVESTIGATION NEEDED]**

## Application fundamentals v1
- Settings controller and service integration **[DONE]**
- More configurable UI values **[IN PROGRESS]**
- Full integration with internationalisation (particularly embarrassing for a non-English project) **[IN PROGRESS]**
- State management rework **[IN PROGRESS]**

## UI revamp v1
- Overall dynamic scaling and scaling fixes
- Chat screen rework v1 **[DONE]**
  - New text entry **[DONE]**
  - New user profiles page **[DONE]**
  - New server profile design **[DONE]**
- Rework settings **[DONE]**
  - Reworked into a hub page
- Rework sidebar **[IN PROGRESS]**
  - The right sidebar is useless and the sidebar settings needs rework.

## Login & Registration Flow
- Support third-party sign-in **[DONE]**
  - Proper SSO support is done
- Support registration **[DONE]**
  - Untested!!!

## UI revamp v2
- New UI framework **[in progress]**
  - Custom sidebar widget **[DONE]**
  - Custom frame widget **[DONE]**
    - Well, we use a dynamic layout widget to build the dashboard dynamically now
  - Custom input widget
  - Custom header v2 **[DONE]**
  - ~~Custom scaffold~~ No longer a good idea

## Branding & Identity
- Welcome screen settings page **[DONE]**
- Credits / developer information screen **[DONE]**
- Supporters card with links **[DONE]**
- Logo replaced with vector icon + text **[DONE]**
- Project monicker: Moonrelay (Alpha)

---

# Future work

Expected timeline: 2026 and beyond

- Custom events (events v3)
  - Git events
  - Map events
  - Realtime audio and video chat
- Application fundamentals v2
  - Optimise for background processes
  - Tighter system integration

# Wishlist

Extremely long-term wishlist that may or may not come to fruition; only
introduced here to remain flexible in the face of the inescapable temporal
burden we carry.

- Server SDK v1
  - Server-side SDK for Matrix protocol
- Client SDK v1
  - Potentially explore new chat protocols as time moves onwards; XMPP was
    once here and now it is no more
  - Who can truly proclaim to know where Matrix will go, especially with the
    strong disdain certain communities show towards the Matrix protocol.
  - I have forked matrix-dart-sdk from Famedly; just in case

# Bad Design

This category captures underlying work needed to fix accumulated design debt.

- FutureBuilders **[DONE]**
- New Chat Timeline **[DONE]**
- Skeletonised loading
  - Better UX
  - Without proper loading animations, the app shows a blank screen on Linux until loaded
  - There is currently a long delay when logging in
- Own blur widget **[DONE]**
- Potential global key issue? **[DONE]**
- Use layout building instead of static layout widgets **[DONE]**
- FIXME Handle cases where user profile response is invalid! **[DONE, I THINK?]**
- FIXME List tiles are not adaptive, causing an exception when the list tile becomes smaller than the title widget **[DONE]**
  - Ended up changing the entire infra behind this to fix it lmao
