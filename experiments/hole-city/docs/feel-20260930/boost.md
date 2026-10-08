# Charged movement boost

The portrait BOOST button previously spent a full charge on a bounded object
pull but never enabled faster movement. A pre-change real viewport touch probe
measured 7.482014656 units/s both before and after the tap. Its score-independent
movement timer stayed at zero, while the pull counter increased to one.
Evidence is retained in `artifacts/feel-20260930/boost-before/` with the original
controller, UI and game source.

The same button now gives 2.5 seconds of 55% faster movement. The existing
limited pull remains, charge is still earned by eating, and the seven-second
cooldown begins on activation. A separate timer preserves Beacon Step's
existing 0.85-second ability: simultaneous effects use one 1.55 multiplier,
without shortening each other or multiplying their speeds together.

The HUD distinguishes charging, ready, boosting and cooldown states. It shows
remaining active/cooldown time, and a rejected tap explains its actual cause.
The touch target and Space shortcut are unchanged. No skin rarity, paid item,
reward amount or movement collision rule changed.

`tests/boost_acceptance.gd` drives real viewport touch events, including a
steering finger held while another taps BOOST. It measures equal-duration
travel at radii 0.85, 6 and 14, observes return to normal speed, and checks
repeated taps, skin-skill coexistence, pause and non-playing states. This is
headless controller and physics evidence, not a browser capture or a phone
performance measurement. Independent review is recorded separately.
