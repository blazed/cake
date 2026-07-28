import assert from "node:assert/strict";
import test from "node:test";
import {
  finalOutput,
  indexAfterMessageBoundary,
} from "./src/backends/pi.ts";

function fakeSession(messages: unknown[]) {
  return { messages } as unknown as Parameters<typeof finalOutput>[0];
}

test("Pi final output is bounded to the current run", () => {
  const session = fakeSession([
    {
      role: "assistant",
      content: [{ type: "text", text: "answer from the previous turn" }],
    },
    { role: "user", content: "new turn" },
    {
      role: "assistant",
      content: [{ type: "thinking", thinking: "failed before answering" }],
    },
  ]);

  assert.equal(finalOutput(session), "answer from the previous turn");
  assert.equal(finalOutput(session, 1), "");
});

test("Pi final output still returns text produced in the current run", () => {
  const session = fakeSession([
    {
      role: "assistant",
      content: [{ type: "text", text: "old" }],
    },
    { role: "user", content: "new turn" },
    {
      role: "assistant",
      content: [{ type: "text", text: "new" }],
    },
  ]);

  assert.equal(finalOutput(session, 1), "new");
});

test("Pi run boundary follows message identity across compaction", () => {
  const boundary = { role: "assistant", content: [] };
  const retained = [
    { role: "assistant", content: [] },
    boundary,
    { role: "user", content: "new turn" },
  ];
  assert.equal(indexAfterMessageBoundary(retained, boundary), 2);

  // Compaction replaced the array and discarded the boundary. Length alone
  // cannot detect this when the replacement is equally long or longer.
  const replaced = [
    { role: "compactionSummary" },
    { role: "user", content: "new turn" },
    { role: "assistant", content: [] },
  ];
  assert.equal(indexAfterMessageBoundary(replaced, boundary), 0);
});
