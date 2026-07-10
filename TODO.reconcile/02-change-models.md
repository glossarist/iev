# 02 — Change + ChangeSet models

## Goal

The core of history reporting. A `Change` captures a single field-level
difference between the termbase snapshot and the live snapshot. A
`ChangeSet` groups all changes for one concept.

## Change

```ruby
Change = Struct.new(:code, :field, :language, :old_value, :new_value,
                    :detected_at, keyword_init: true)
```

Fields:
- `code`: IEV code (e.g. "102-01-01")
- `field`: `:designation` | `:definition` | `:notes` | `:examples` | `:status` | `:language_added` | `:language_removed`
- `language`: ISO 639-2 code ("eng", "fra", nil for concept-level)
- `old_value`: the termbase value (nil for additions)
- `new_value`: the live value (nil for removals)
- `detected_at`: date the change was observed (mirror date)

## ChangeSet

```ruby
class ChangeSet
  include Enumerable
  def initialize(code)
  def add(change)
  def each
  def empty?
  def by_field(field)
  def by_language(lang)
  def summary  # hash of field => count
end
```

## Checklist

- [x] Implement Change (Struct)
- [x] Implement ChangeSet
- [x] Spec: ChangeSet query methods
- [x] Spec: ChangeSet#summary
