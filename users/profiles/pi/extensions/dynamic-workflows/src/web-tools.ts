/**
 * Real web tools for research workflows. These execute in the extension host
 * process (which has network access), not in a subagent sandbox, so they perform
 * genuine HTTP requests via Node's fetch.
 *
 * - web_search: Exa (api.exa.ai) when an EXA_API_KEY / ~/.pi/web-search.json key
 *   is configured (the same key the pi-web-access extension uses), else a
 *   best-effort Bing HTML scrape. Returns result {url, title}.
 * - web_fetch:  fetch a URL and return readable text (HTML stripped, truncated)
 *
 * Subagents run extension-free (agent.ts noExtensions), so they can't reach the
 * pi-web-access tools; this reuses its key/endpoint without loading it.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { defineTool, type ToolDefinition } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const UA =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

async function fetchText(url: string, timeoutMs = 15000): Promise<{ status: number; body: string }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { headers: { "user-agent": UA }, signal: controller.signal, redirect: "follow" });
    return { status: res.status, body: await res.text() };
  } finally {
    clearTimeout(timer);
  }
}

function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<\/(p|div|li|h[1-6]|tr|br)>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function parseBingResults(html: string, limit: number): Array<{ url: string; title: string }> {
  const out: Array<{ url: string; title: string }> = [];
  const seen = new Set<string>();
  for (const m of html.matchAll(/<h2[^>]*>\s*<a[^>]+href="(https?:\/\/[^"]+)"[^>]*>([\s\S]*?)<\/a>/g)) {
    const url = m[1];
    if (/\.bing\.com|go\.microsoft\.com/.test(url) || seen.has(url)) continue;
    seen.add(url);
    out.push({ url, title: m[2].replace(/<[^>]+>/g, "").trim() });
    if (out.length >= limit) break;
  }
  return out;
}

/**
 * Exa API key, from the same sources pi-web-access reads: the EXA_API_KEY env
 * var, else ~/.pi/web-search.json's `exaApiKey`. Read on demand (cheap, and these
 * tools run in the host, not the TUI render path).
 */
function getExaApiKey(): string | undefined {
  const fromEnv = process.env.EXA_API_KEY?.trim();
  if (fromEnv) return fromEnv;
  try {
    const path = join(homedir(), ".pi", "web-search.json");
    if (existsSync(path)) {
      const cfg = JSON.parse(readFileSync(path, "utf-8")) as { exaApiKey?: unknown };
      if (typeof cfg.exaApiKey === "string" && cfg.exaApiKey.trim()) return cfg.exaApiKey.trim();
    }
  } catch {
    // Malformed/unreadable config -> behave as if no key (fall back to Bing).
  }
  return undefined;
}

/** Search via Exa's REST API. Throws on transport/HTTP error so the caller can fall back. */
async function searchExa(
  apiKey: string,
  query: string,
  limit: number,
  timeoutMs = 15000,
): Promise<Array<{ url: string; title: string }>> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch("https://api.exa.ai/search", {
      method: "POST",
      headers: { "x-api-key": apiKey, "content-type": "application/json" },
      body: JSON.stringify({ query, type: "auto", numResults: limit, contents: { highlights: true } }),
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`Exa API ${res.status}: ${(await res.text()).slice(0, 200)}`);
    const data = (await res.json()) as { results?: Array<{ url?: string; title?: string }> };
    const out: Array<{ url: string; title: string }> = [];
    for (const r of data.results ?? []) {
      if (!r?.url) continue;
      out.push({ url: r.url, title: (r.title || r.url).trim() });
    }
    return out;
  } finally {
    clearTimeout(timer);
  }
}

async function searchBing(query: string, limit: number): Promise<Array<{ url: string; title: string }>> {
  const { body } = await fetchText(`https://www.bing.com/search?q=${encodeURIComponent(query)}`);
  return parseBingResults(body, limit);
}

const formatResults = (results: Array<{ url: string; title: string }>): string =>
  results.map((r, i) => `${i + 1}. ${r.title}\n   ${r.url}`).join("\n");

/** Optional hooks for the web tools. `log` records which search backend ran. */
export interface WebToolsOptions {
  log?: (message: string) => void;
  maxChars?: number;
}

/** A tool that searches the web and returns result URLs + titles (Exa, else Bing). */
export function createWebSearchTool(opts: Pick<WebToolsOptions, "log"> = {}): ToolDefinition {
  return defineTool({
    name: "web_search",
    label: "Web Search",
    description: "Search the web and return a list of result URLs and titles. Use before web_fetch to find sources.",
    promptSnippet: "Search the web for sources",
    parameters: Type.Object({
      query: Type.String({ description: "The search query." }),
      count: Type.Optional(Type.Number({ description: "Max results (default 6)." })),
    }),
    async execute(_id, params: { query: string; count?: number }) {
      const limit = Math.min(Math.max(params.count ?? 6, 1), 10);
      const apiKey = getExaApiKey();
      const breadcrumb = (source: string, n: number | string) =>
        opts.log?.(`web_search[${source}] ${JSON.stringify(params.query)} → ${n}`);

      // Prefer Exa when configured; on empty/failed Exa, fall back to Bing.
      if (apiKey) {
        try {
          const results = await searchExa(apiKey, params.query, limit);
          if (results.length) {
            breadcrumb("exa", results.length);
            return { content: [{ type: "text", text: formatResults(results) }], details: { results, source: "exa" } };
          }
        } catch {
          // Fall through to Bing rather than hard-failing the search.
        }
      }

      try {
        const results = await searchBing(params.query, limit);
        breadcrumb("bing", results.length);
        const text = results.length
          ? formatResults(results)
          : "No results parsed. Try a different query or fetch a known URL directly.";
        return { content: [{ type: "text", text }], details: { results, source: "bing" } };
      } catch (error) {
        breadcrumb("none", "failed");
        return {
          content: [{ type: "text", text: `web_search failed: ${error instanceof Error ? error.message : error}` }],
          details: { results: [] as Array<{ url: string; title: string }>, source: "none" },
        };
      }
    },
  }) as unknown as ToolDefinition;
}

/** A tool that fetches a URL and returns readable text. */
export function createWebFetchTool(maxChars = 6000): ToolDefinition {
  return defineTool({
    name: "web_fetch",
    label: "Web Fetch",
    description: "Fetch a URL and return its readable text content (HTML stripped, truncated).",
    promptSnippet: "Fetch a URL's text",
    parameters: Type.Object({
      url: Type.String({ description: "The absolute URL to fetch." }),
    }),
    async execute(_id, params: { url: string }) {
      try {
        const { status, body } = await fetchText(params.url);
        const full = htmlToText(body);
        const truncated = full.length > maxChars;
        const text = truncated ? full.slice(0, maxChars) : full;
        const notice = truncated
          ? `\n\n[truncated: showing ${maxChars} of ${full.length} chars — fetch a more specific URL/section for the rest]`
          : "";
        return {
          content: [{ type: "text", text: `HTTP ${status} ${params.url}\n\n${text}${notice}` }],
          details: { status, url: params.url, truncated, totalChars: full.length },
        };
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `web_fetch failed for ${params.url}: ${error instanceof Error ? error.message : error}`,
            },
          ],
          details: { status: 0, url: params.url },
        };
      }
    },
  }) as unknown as ToolDefinition;
}

/** Both web tools, for injecting into a research workflow's agents. */
export function createWebTools(opts: WebToolsOptions = {}): ToolDefinition[] {
  return [createWebSearchTool({ log: opts.log }), createWebFetchTool(opts.maxChars)];
}
