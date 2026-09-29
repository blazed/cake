# jq vs Nushell Quick Reference

Nushell can replace many `jq` filters by parsing JSON into native Nu values,
transforming them with pipeline commands, then optionally serializing back to
JSON.

## Parse and Emit JSON

```nu
# jq reads JSON by default; Nu parses explicitly
'{"title":"jq vs nu"}' | from json

# File input
open data.json

# Emit JSON
open data.json | to json
open data.json | to json | save --force out.json
```

## Common Translations

```nu
# jq '.name'
'{"name":"Alice","age":30}' | from json | get name

# jq '.[] | select(.age > 28)'
open people.json | where age > 28

# jq '.[] | select(.age > 28) | .name'
open people.json | where age > 28 | get name

# jq 'map(. * 2)'
'[1,2,3]' | from json | each { $in * 2 }

# jq 'sort'
'[3,1,2]' | from json | sort

# jq 'unique'
'[1,2,2,3]' | from json | uniq

# jq '.name | split(" ") | .[0]'
'{"name":"Alice Smith"}' | from json | get name | split words | get 0

# jq 'if .age > 18 then "Adult" else "Child" end'
'{"age":30}' | from json | if $in.age > 18 { "Adult" } else { "Child" }

# jq 'map(select(. != null))'
'[1,null,3]' | from json | compact

# jq '{name: .name, age: (.age + 5)}'
'{"name":"Alice","age":30}' | from json | {name: $in.name, age: ($in.age + 5)}
```

## Tables and Records

A JSON array of objects becomes a Nu table, so many operations are simpler than
jq record construction.

```nu
# Update a column
open items.json | update price { |row| $row.price * 2 }

# Add a derived column
open items.json | insert total { |row| $row.price * $row.qty }

# Select columns
open items.json | select name price

# Extract a column as a list
open items.json | get name
```

## Nested Data

```nu
# jq '.data[].values[] | select(. > 3)'
open nested.json | get data.values | flatten | where {|x| $x > 3}

# Optional cell-path access, like jq '.foo?'
open maybe.json | get -o foo.bar
# or in records/closures: $row.foo?
```

## Group and Aggregate

```nu
# jq 'group_by(.category) | map({category: .[0].category, sum: map(.value) | add})'
open items.json
| group-by --to-table category
| update items { |row| $row.items.value | math sum }
| rename category sum

# Filter after aggregate
open items.json
| group-by --to-table category
| update items { |row| $row.items.value | math sum }
| rename category value
| where value > 17

# jq 'reduce .[] as $item (0; . + $item.value)'
open items.json | reduce -f 0 { |item, acc| $acc + $item.value }

# Average
open scores.json | get score | math avg
```

## When jq May Still Be Better

- Existing complex recursive jq filters that would take time to port.
- Streaming enormous JSON in a memory-sensitive pipeline.
- Environments where Nu is not available.

Otherwise, prefer Nu when you want readable, typed, shell-native data pipelines.

Official cookbook: https://www.nushell.sh/cookbook/jq_v_nushell.html
