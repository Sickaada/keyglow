# Advanced animation engine: approval required

The existing firmware supports one selected effect, global HSV, speed and two extra colors. It does not accept per-key assignments, arbitrary keyframes, composited layers, duration, easing, direction, wave width or intensity controls.

This redesign provides an editor for the existing split, gradient, color-fade and color-wave effects. No timeline or layer controls are presented as working features. The editor explains this limit. Its preview transport is local; Apply sends through the existing command sender.

A full timeline editor requires a separately approved engine change:
1. Versioned capability negotiation and acknowledgement; installed firmware cannot currently be queried for capabilities.
2. On-keyboard timeline/layer renderer, bounded storage and an upload protocol with checksums and transactional validation.
3. Per-key addressing tied to the 84-LED matrix, keyframe interpolation, loop/easing/duration support and runtime limits.
4. Firmware size/performance/battery measurements, recovery firmware and a separate flash authorization.
5. A matching editor document format, accurate shared simulation, and integration tests on hardware.

Streaming 60 RGB frames/second over the current lock-light side channel is not viable. A host-side animation loop sending commands every frame is not an acceptable substitute. No firmware changes or reflashing are included in this UI task.
