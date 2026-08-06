import type { Theme, ToolRenderResultOptions } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

interface ToolResult {
  readonly content: readonly { readonly type: string; readonly text?: string }[];
}

type RenderOptions = ToolRenderResultOptions & { readonly isError?: boolean };

export function compactCall(
  theme: Theme,
  label: string,
  detail = "",
): Text {
  const suffix = detail ? ` ${theme.fg("accent", detail)}` : "";
  return new Text(theme.fg("toolTitle", theme.bold(label)) + suffix, 0, 0);
}

export function compactResult(
  result: ToolResult,
  options: RenderOptions,
  theme: Theme,
  summary: string,
): Text {
  if (options.isPartial) {
    return new Text(theme.fg("warning", summary), 0, 0);
  }

  const raw = result.content.find((item) => item.type === "text")?.text;
  const color = options.isError ? "error" : "success";
  const message = options.isError ? raw?.split(/\r?\n/, 1)[0] ?? summary : summary;
  let text = theme.fg(color, `${options.isError ? "x" : "✓"} ${message}`);
  if (options.expanded && raw && raw !== message) text += `\n${raw}`;
  return new Text(text, 0, 0);
}
