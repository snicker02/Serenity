Serenity
Version: 3.0 ("The Bloom, Flow & Orbit Update")

Engine: Godot 4.x

Serenity is a generative art tool designed to bridge the gap between mathematical precision and organic flow. It allows users to sketch complex geometric algorithms in real-time, layering wireframe aesthetics with smart, invisible masking logic to create depth without obscuring detail.

✨ New in Version 3.0
Version 3.0 introduces three major generative algorithms that expand the tool from static geometry into organic flows, floral patterns, and complex mechanical loops.

🌸 Flower Mode (Radial Waves)
Generates organic, wave-based radial patterns that mimic petals, starfish, or soundwaves.

Master Shape Logic: Uses a stable "Master Ring" calculation that scales perfectly without physics drift.

Vortex Effect: Apply Twist to rotate inner rings for dynamic motion.

Shape Control: Toggle Round Corners for soft petals or sharp thorns; use Stabilize Ends to switch between vibrating waves and outward-facing star shapes.

🪐 Orbit Mode (Spirograph Engine)
A geometric loop engine that creates intricate hypotrochoid-style patterns.

Stable Geometry: Unlike traditional physics simulations, Orbit uses a locked-integer scaling algorithm to ensure loops always close perfectly.

Wireframe & Depth: Utilizes an "Invisible Mask" system to block background lines while keeping the shape itself transparent and lightweight.

Controls: Adjust Twist (Gear Ratio) and Wobble (Loop Depth) to move between simple loops and dense mesh-like structures.

🌊 Current Mode (Perlin Flow Fields)
Draw rectangular zones of flowing lines that mimic liquid, wood grain, or rain.

Adaptive Direction: Automatically detects the aspect ratio of your drawn box to switch between "River" (Horizontal) and "Rain" (Vertical) flow.

Grid Locking: Lines snap to a world grid, allowing you to draw multiple adjacent fields that align seamlessly.

🎨 Core Patterns
In addition to the new V3.0 modes, Serenity includes its foundational generative engines:

Aura (Ripple): Creates smooth, equidistant echoes of a drawn line, simulating ripples in water.

Paradox (Spiral): Generates impossible geometric spirals that twist inward based on a 2-point axis.

Cellular: Uses Voronoi diagrams to generate biological, cell-like structures that adapt to the canvas boundaries.

🎮 Controls
Mouse
Left Click + Drag:

Radial Modes (Flower/Orbit): Define the center and drag outward to set radius.

Current Mode: Drag to define the flow area box.

Point Modes: Draw freehand lines or place control points.

Right Click: Cancel the current shape or finish a line segment.

Keyboard
Spacebar: Freeze the current live shape. This stamps the geometry onto the canvas and applies the invisible mask, allowing new shapes to be drawn "behind" it.

UI Parameters
Line Width / Spacing / Count: Universal controls for density and weight.

Wobble: Adds noise or loop depth depending on the active mode.

Twist: Controls rotation, frequency, or gear ratios.

Stabilize Ends / Round Corners: Toggles specific math modifiers for Orbit and Flower modes.

🛠️ Technical Highlights
Smart Masking: Serenity uses a custom "Invisible Footprint" system. When a shape is frozen, the engine calculates a solid polygon mask that is added to the scene's logic but not rendered visually. This allows wireframe shapes to overlap cleanly, respecting depth and occlusion without needing opaque backgrounds.

Unified Input Handler: A rewritten input pipeline in V3.0 ensures that all modes share the same intuitive "Draw -> Freeze -> Cancel" workflow.

🚀 Installation & Usage
Clone this repository.

Open the project folder in Godot Engine 4.x.

Run the main scene to start creating.

Created by Brad Stefanov with assistance from Gemini 
