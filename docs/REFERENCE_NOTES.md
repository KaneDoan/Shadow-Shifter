# Native reference limits

The local Katana ZERO recovery at `D:/Game Decompile/Katana` was consulted as a behavioral reference for quick sword action, motion trails and fast retries. This Godot implementation is new GDScript using the approved ShadowShift specification; recovered artwork, audio and native code are not included.

The recovered `GameCode/gml_Script_player_attack.c` contains an identifiable call to `gml_Script_create_motion_trail` near line 101. That supports the narrow observation that the recovered attack script calls the named trail script. Adjacent anonymous fields, numeric RValue type tags, conversion helpers and address-based constants do not establish attack eligibility, exact damage or timing. Qwen's preliminary interpretation of those fields was not treated as fact.

The 96-pixel travel range, vision settings, sword timings, alarm rules and one-hit behavior come from the user's GDD and approved hybrid amendments. They are not claimed as extracted Katana ZERO constants. Original GDD SHA-256: `D6FC4682A8FBD488E84AEEA431733DFDAD0870D76AB82DFCEEBBA6BBE45062EE`.
