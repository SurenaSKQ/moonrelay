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

- Support chat event types v1
  - Chat timeline needs rework.
  - Text Messages **[DONE]**
  - Images **[DONE]**
    - Still needs some work tbh, we need a dedicated image view screen
  - Audio **[DONE]**
    - No in-app player right now
  - Video
  - Files **[DONE]**
    - Needs some work on the widget
- Chat events v2
  - Dynamically built text with inline images
  - Code blocks support
  - Right click menu
  - Replies
  - Threads
  - Stickers
- Application fundamentals v1
  - Settings controller and service integration
  - More configurable UI values
  - Full integration with internationalization (this is particularly embarassing for a non-english project)
  - State management rework
- UI revamp v1
  - Overall increase the dynamic scaling potential of the UI and fix scaling
  - Chat screen rework v1
    - New text entry
    - New user profiles page
    - New server profile design
  - Rework settings
    - Or more accurately, make settingsview as it is only a stub
  - Rework sidebar
- Login & Registeration Flow
  - Support third party sign in
  - Support registeration
- UI revamp v2
  - New UI framework **[in progress]**
    - Custom sidebar widget
    - Custom frame widget **[•]**
    - Custom input widget
    - Custom header v2 **[•]**
    - ~~Custom scaffold **[•]**~~ No longer a good idea

# Future work

Expected timeline: 2026 and beyound

- Custom events (events v3)
  - Git events
  - Map events
  - Realtime audio and video chat
- Application fundamentals v2
  - Optimize for background process
  - Tighter system integration

# Wishlist

Extremely long term wishlist that may or may not come to fruitition; only introduced here for gathering options
to remain flexible in the face of the inescapable temporal burden we carry.

- Server SDK v1
  - Server-side SDK for Matrix protocol
- Client SDK v1
  - Potentially explore new chat protocols as time moves onwards; XMPP was here once and how it is no more
  - who can trully proclaim to know where Matrix will go, especially with the strong disdain certain communities
  - show towards the Matrix protocol.
  - I have forked matrix-sdk-lite from Famedly; just in case

# Bad Design

This category is the underlying work that needs to be done to fix the terrible design I accumulated over the past 2 years.

- FutureBuilders **[in progress]**
  - There is a LOT of code that need to use FutureBuilders with placeholders to get data.
- New Chat Timeline
  - That whole thing is a mess
- Skeletonized loading
  - Better UX
  - Without proper loading animations; the app shows a blank screen on Linux until loaded
  - Currently there is a long delay when logging in
- Own blur widget **[•]**
- Potential global key issue?
- Use layout building instead of static layout widgets **[in progress]**
- FIXME Handle cases where user profile response is invalid!
- FIXME List tiles are not adaptive, causing an exception when the list tile becomes smaller than title widget
