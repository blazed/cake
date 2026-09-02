# Global instructions

- Repositories use JJ with a Git backend. Prefer JJ over Git. Load `jj-core`
  before VCS work and `jj-todo` for multi-revision implementation work.
  Never use `jj git push --allow-private`.

- The user's interactive shell is Nushell. User-facing commands must be
  Nushell-compatible and fenced `nu`. Use explicit `bash -c` only when Bash
  is actually required.
