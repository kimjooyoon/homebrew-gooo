# Tap maintenance

- Use immutable public release URLs and verified archive SHA-256 values.
- Preserve the complete upstream runtime bundle, manifests and license notices.
- Keep business behavior in upstream Gooo sources; this repository owns only installation and client smoke tests.
- Test actual stdio initialization, tool discovery, a typed decision and malformed-input refusal. No model inference is required.
- Never change a user's agent configuration or install a compiler as part of this formula.
- Describe supported platforms and distinguish a finite installation test from upstream behavior validation or outside adoption.
- Do not publish or replace a release archive from this repository.
