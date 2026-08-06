import assert from "node:assert/strict";
import test from "node:test";
import type { Theme } from "@earendil-works/pi-coding-agent";
import { compactResult } from "./src/tool-renderer.ts";

const theme = {
  fg: (_color: string, text: string) => text,
} as Theme;

const result = { content: [{ type: "text", text: "full output" }] };

test("compact results reveal raw output only when expanded", () => {
  const collapsed = compactResult(result, { expanded: false, isPartial: false }, theme, "done");
  const expanded = compactResult(result, { expanded: true, isPartial: false }, theme, "done");

  assert.doesNotMatch(collapsed.render(80).join("\n"), /full output/);
  assert.match(expanded.render(80).join("\n"), /full output/);
});
