# Architecture:
## Sub-applications:
- Renderer
 - Starting simple: Each Zone gets a static rectangle,
 and can change its color.
 - Later versions with less time restriction should allow:
  - Overlapping Zones
  - Actual sprites other than single rectangles
- Zones
 - macro-module
 - use GenServer
 - Knows what Objects are in it
  - (pid and tags)
 - call it for contained Objects (of specific kind)
 - Has a list of atoms as tags
 - Has a function: Based on contained objects, produce a color
  - TODO for later version: Add graphics other than single colors.
- Objects
 - Anything implementing the necessary protocol,
 wrapped in an Agent.
 - Protocol has default implementation written up for Maps.
- Rule system
 - Rule API
  - Rule has a tag. Zone has a rule.
  - Each update, call the Rule's function for each object with the tag,
  and also pass the Zone.
- UI Forwarder
 - Objects can be tagged as getting keyboard and/or mouse events
 - When keyboard input happens, send it to all zones,
 which then send it to all objects with the tag.
 - Mouse input goes only to the zone(s) the mouse is touching.

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

