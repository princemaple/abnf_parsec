## v1.2.1 - 2022-02-05

### Fixed

- String concatenation bug caused by case insensitivity implementation

## v1.2.0 - 2021-03-17

### Changed

Now strings default to be case insensitive

## v1.1.0 - 2020-12-28

### 🚀 Features

- Rfc7405 @guenni68 (#16)
  - Adds case-insensitive string matching but haven't switched default to case-insensitive yet

## v1.0.0 - 2020-11-03

Not much, just that it's stable enough

- handle 0 repeat @princemaple (#15)

## v0.1.2 - 2020-03-06

### Added

- `pre/post_traverse` transformation

## v0.1.1 - 2020-02-10

### Changed

- Require Elixir 1.10

### Added

- Allow adding extra UTF8 range to comments
  - `test/fixture/dhall.abnf` has this line `; "∀" / "forall"`

## v0.1.0 - 2020-02-09

Initial release
