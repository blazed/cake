// Template for self-authored Pi extensions managed by Nix.
//
// Extensions live in `users/profiles/pi/extensions/` in the cake repo and are
// symlinked into `~/.pi/agent/extensions/` (auto-discovered by Pi: it loads
// `extensions/*.ts` and `extensions/*/index.ts`). Edit or delete this one.
//
// See https://pi.dev/docs/latest/extensions for the ExtensionAPI surface
// (pi.on(event), pi.registerTool(...), pi.registerCommand(...)).
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (_pi: ExtensionAPI) {
  // no-op template — register tools/commands or subscribe to events here.
}
