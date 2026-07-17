# Security

Please report suspected vulnerabilities privately through GitHub's security advisory feature rather than opening a public issue.

Mac Input Lock requires Accessibility permission to suppress global input. It does not log or transmit input, use the network, install a privileged helper, or run a background service. The event buffer exists only in memory and retains at most the number of characters in the configured unlock sequence.

Security fixes are released as signed and notarized GitHub release artifacts. There is no automatic updater in the application.
