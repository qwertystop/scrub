# Architecture:
## Sub-applications:
- Renderer
 - Stores non-changing information (like sprites) for each object
 - Gets changing information (any transforms) each frame
 - Each Zone has a place on-screen to be rendered in, and a background to put there
 - Zone areas cannot overlap
  - Removes some graphical options, but graphics are not the point of this project
- Zones
 - ZoneRegistry
  - use GenServer
  - Can map from any Zone to all connected Zones
   - Connection sets are tagged, allowing e.g. directions to matter
  - Zones arranged in arbitrary graph
 - Zone
  - macro-module
  - use Agent
  - Knows what Objects are in it
   - (pid and tags)
  - call it for contained Objects (of specific kind)
  - Has a list of atoms as tags
  - Has a function: Given an Object's in-zone position, produce a transform for the renderer
   - Literal position isn't as much of a thing
- Objects
 - ObjectRegistry
  - use GenServer
 - Object
  - macro-module
  - use Agent
  - Created in/by a Zone, store pid of that Zone
  - State is a map, which can include tags (atom mapping to true)
  - Has a list of functions following Rule API
  - Has an automatic update function
  - Responds to messages passed from UI forwarder
  - Has a location, but relative to the Zone
- Rule system
 - Rule API
  - foo({:tag, pid}, {:tag, pid}, :samezone) # (or :connzone)
  - Given two objects with specific tags, send messages to those objects
  - Objects should handle those messages appropriately
  - Each update, all Zones try to call rules for all object pairs
  - Game should have a single Rules module to leverage pattern-matching
- UI Forwarder
 - Send messages to object manager containing keyboard input
  - Not bothering with other input devices for the first version

# Basic game loop:
1. Concurrently:
 - Each zone runs all applicable rules
  - Concurrency means any given interaction could happen in a two-frame window
 - UI forwarder collects and sends along messages from user input
 - Each object does its per-frame update
  1. Handles any messages (from Zones/Rules, from user input, etc)
  2. Does the standard self-only state update
   - Make sure that message handling and standard update don't overlap.
    - That might be automatic?
   - All creation and destruction of Objects must be told to Zone
    - All modification of game state is inside an Object
  3. Each object sends the renderer its new position and Zone
  4. Each object tells its Zone it's done
   - Zone keeps count, tells Renderer when it's ready to render
2. Rendering happens (for each Zone separately, in parallel)
 - Objects send the Renderer their current position and what Zone they're in
  - Position is in-zone
  - Renderer asks Zone to turn position into a transform to render within that Zone
 - Renderer renders Zone
 - When all Zones are rendered, draw to screen
 
## Game loop reduced to pipeline
**1-3 all happen concurrently.**
1. Zones check rules
2. Input is forwarded
3. Objects self-update accordingly
4. Renderer renders all zones in parallel
5. Draw to screen

