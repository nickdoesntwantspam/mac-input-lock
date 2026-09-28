# Security

Please report suspected vulnerabilities privately through GitHub's security advisory feature rather than opening a public issue.

Mac Input Lock requires Accessibility permission to suppress global input. It does not log or transmit input, install a privileged helper, or run a background service. The event buffer exists only in memory and retains at most the number of characters in the configured unlock sequence.

The only network activity is a manual or user-approved automatic software-update check. Anonymous system profiling is disabled. Updates are Developer ID signed and notarized, update archives use an EdDSA signature, the appcast is signed, and archives are verified before extraction. Update installation and relaunch are deferred until input locking is completely inactive.
