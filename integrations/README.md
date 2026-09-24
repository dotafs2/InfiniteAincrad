# Preserved local integrations

[LocalJev](localjev/README.md) is the previously untracked local TypeScript/Bun service source used alongside this project. The original MIT license, source, tests, lockfile, sample configuration and existing documentation are preserved. [The source manifest](localjev-source-manifest.json) records every copied file hash and the limits of the known provenance.

This upload does not connect the service to the canonical resident provider, start servers, install packages or invoke any model. Installed dependencies, private environment configuration, evaluation output and caches are excluded. Existing Chinese deployment notes are historical source documentation; current project-authored documentation remains English.

The copied `localjev/StartLocalJev.cmd` is a historical launcher with a relative-path assumption and a smaller-model default than the separate entry launcher. It is retained unchanged for completeness. For source inspection or future setup, work directly in `integrations/localjev` and consult its package scripts; verify local model and provider settings before an explicitly authorized runtime session.
