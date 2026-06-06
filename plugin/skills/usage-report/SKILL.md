---
description: Report and analyze Claude/LLM token usage and cost using the McDuck MCP tools. Use when the user asks how much they've spent, their token usage, cost over a period, daily trends, or which model/day is most expensive.
---

# McDuck usage report

Answer questions about Claude/LLM token spend using the McDuck MCP server
(`mcduck`). The data comes from `ccusage`, parsed by McDuck.

## Tools

- `mcp__mcduck__usage_summary` — total tokens and cost (USD) over an optional
  date range. Arguments: `start`, `end` (both `yyyy-MM-dd`, inclusive, optional).
- `mcp__mcduck__daily_usage` — per-day token totals and cost over a range.
- `mcp__mcduck__model_breakdown` — per-model token totals and cost over a range.

All three accept the same optional `start`/`end`. Omit both for all-time.

## How to use

1. **Resolve the period to explicit dates.** For "today", "this week", "this
   month", compute concrete `start`/`end` (you know today's date from context)
   and pass them. For "all time", omit both.
2. **Pick the right tool**: a single number → `usage_summary`; a trend or
   "which day" → `daily_usage`; "which model" / "what am I spending it on" →
   `model_breakdown`.
3. **Lead with the headline**: cost in USD and total tokens for the period.
   Then add the most useful detail (biggest day, top model, active days).
4. **For cost-reduction questions**, call `model_breakdown` and point at the
   highest-cost model, and `daily_usage` for spikes.

## Notes

- Costs are USD; token counts are integers.
- If a tool result is flagged as an error mentioning Bun or ccusage, tell the
  user to install Bun and ccusage (the McDuck menu-bar app's setup screen does
  this for them, or `bun install -g ccusage` / `bunx ccusage`).
