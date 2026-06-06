# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in ARWarp, please **do not** open a public issue. Instead, report it privately:

1. Email the maintainer with details of the vulnerability.
2. Include steps to reproduce, affected versions, and any suggested mitigations.
3. You will receive a response within 72 hours with next steps.

## Supported Versions

Only the latest release on the `main` branch receives security updates.

| Version | Supported |
|---------|-----------|
| latest  | Yes       |

## Scope

Security concerns relevant to ARWarp include:
- Unsafe memory access in Metal shaders or vertex buffer handling
- Microphone or camera access beyond documented AR/audio use
- Crash or hang conditions triggered by malformed audio input
- Dependency supply chain issues

## Acknowledgments

We appreciate responsible disclosure and will acknowledge contributors who report valid issues (with permission).
