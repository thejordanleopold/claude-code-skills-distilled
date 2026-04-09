---
name: refactoring
description: |
  Use when improving code structure, readability, or testability without changing behavior.
  Apply when functions are too long, code is duplicated across files, names don't match intent,
  dependencies are tangled, tests are hard to write, or preparing for a large rewrite using
  the strangler fig pattern. Triggers: code smells (long method, feature envy, data clumps,
  primitive obsession), "hard to understand", "hard to change", "hard to test", "clean this up".
---

# Refactoring

Improve code structure without changing behavior.

**Core principle:** Refactoring = structure change, behavior unchanged. Tests must be green before AND after every step. One change at a time.

## When to Use

- Adding features is getting slower (tangled dependencies)
- Functions are longer than 50 lines
- Same logic exists in 2+ places
- Tests are hard to write (tight coupling)
- Names no longer match what the code does
- Preparing for a major rewrite (strangler fig)

## When NOT to Use

- Tests are failing (fix tests first)
- You need to add new behavior (refactor separately, then add)
- During an incident or under time pressure (document debt, defer)
- The code works and nobody reads it

---

## The Non-Negotiable Protocol

```
1. All tests green (baseline)
2. Grep for ALL usages of what you're changing
3. Make ONE change
4. Run tests
5. Commit if green
6. Repeat
```

**Never combine refactoring with feature changes in the same commit.** This makes regressions impossible to isolate.

### Two Hats Rule

Never mix refactoring and feature/behavior changes in the same commit.
- **Refactoring hat:** change structure, NOT behavior — tests must pass unchanged before and after
- **Feature hat:** change behavior — separate commit, separate review

When you notice a bug or improvement opportunity during refactoring: note it, finish the refactor, then switch hats and address it separately.

---

## Common Refactorings

### Extract Method

When: block of code does one thing, appears in 2+ places, or is too long to scan.

```python
# Before
def process_payment(card, amount):
    if not card or not (1000 <= card.number <= 9999999999999999):
        return False
    if card.expiry_month < 1 or card.expiry_month > 12:
        return False
    # ... actual processing

# After: validation extracted and independently testable
def is_valid_card(card) -> bool:
    return (card is not None
            and 1000 <= card.number <= 9999999999999999
            and 1 <= card.expiry_month <= 12)

def process_payment(card, amount):
    if not is_valid_card(card):
        return False
    # ... actual processing
```

**Steps:**
1. Identify block (does one thing, 3-15 lines)
2. Grep: does this block appear elsewhere? (duplication confirms the extract)
3. Determine inputs and outputs
4. Extract, name clearly, test

### Rename for Clarity

When: name doesn't reveal intent, or intent has changed since the name was chosen.

```python
# Before: what does calc() calculate? what are x, y?
def calc(x, y):
    return x * y * 0.08

# After: intent is obvious
def calculate_tax(subtotal: float, tax_rate: float) -> float:
    return subtotal * tax_rate
```

**Steps:**
1. Grep for ALL usages first — missing one causes a runtime error
2. Rename everywhere consistently (IDE refactor > manual find-replace)
3. Run tests

### Move Method (Fix Feature Envy)

When: a method uses more data from another class than its own.

```python
# Before: User.calculate_order_total uses Order data — wrong home
class User:
    def calculate_order_total(self, order):
        return sum(item.price for item in order.items)

# After: method lives where its data lives
class Order:
    def calculate_total(self) -> float:
        return sum(item.price for item in self.items)
```

### Introduce Parameter Object

When: 4+ parameters that appear together at multiple call sites.

```python
# Before: 8-parameter function
def create_user(first_name, last_name, email, phone, address, city, state, zip_code):
    ...

# After: grouped into a value object
@dataclass
class UserProfile:
    first_name: str
    last_name: str
    email: str
    phone: str
    address: str
    city: str
    state: str
    zip_code: str

def create_user(profile: UserProfile):
    ...
```

### Remove Dead Code

When: function/class/variable has zero callers.

```bash
# Verify zero usages before deleting
grep -r "unused_function" src/
# If empty output: safe to delete
```

Delete it. Do not comment it out. Version control preserves history.

### Replace Conditional with Polymorphism

When: complex if/else or switch on type discriminates behavior.

```python
# Before: type-switching logic scattered everywhere
def get_discount(user):
    if user.type == 'premium':
        return 0.20
    elif user.type == 'standard':
        return 0.10
    else:
        return 0.0

# After: each type owns its behavior
class PremiumUser(User):
    def get_discount(self) -> float:
        return 0.20

class StandardUser(User):
    def get_discount(self) -> float:
        return 0.10
```

### Replace Primitive with Value Object

When: same primitive (string, int) used to mean different things.

```python
# Before: easy to pass wrong string type
def transfer(from_account_id: str, to_account_id: str, amount: float):
    ...

# After: type system prevents mix-ups
class AccountId(str):
    def __new__(cls, value: str):
        if not value.startswith('ACC-'):
            raise ValueError(f"Invalid account ID: {value}")
        return super().__new__(cls, value)

def transfer(from_id: AccountId, to_id: AccountId, amount: float):
    ...
```

---

## Code Smells Quick Reference

| Smell | Symptom | Refactoring |
|-------|---------|-------------|
| **Long Method** | >50 lines, hard to scan | Extract Method |
| **Long Parameter List** | >4 parameters | Introduce Parameter Object |
| **Duplicate Code** | Same logic in 2+ places | Extract Method or class |
| **Feature Envy** | Method uses another class's data more than its own | Move Method |
| **Data Clumps** | Same 3-4 fields always appear together | Extract class |
| **Primitive Obsession** | Strings/ints used as domain concepts | Value Object |
| **Switch Statements** | Complex if/else chains on type | Polymorphism or strategy |
| **Temporary Field** | Field only populated in some code paths | Extract class |
| **Dead Code** | Code never called | Delete |

---

## Strangler Fig Pattern (Large Rewrites)

For rewrites too large to do all at once:

```
Phase 1: Build new alongside old
  - New code runs in shadow mode (no production traffic)
  - Old system handles 100% of requests

Phase 2: Gradual migration
  - Route 5% of traffic to new system
  - Compare outputs, fix bugs
  - Increase: 5% → 25% → 50% → 100% over weeks

Phase 3: Retire old
  - Old system off-path for 2 weeks (safety net)
  - Delete old code
```

Never do a "big bang" rewrite. Always have a rollback path at each phase.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Refactoring + feature change in same commit | Separate commits for structure vs behavior |
| Rename without Grep first | Always verify all usages before renaming |
| Commenting out dead code | Delete it — git history preserves it |
| Abstracting after 1 use | Wait for 3+ concrete instances before extracting |
| No tests before refactoring | Write characterization tests first if none exist |
| Large refactoring without commits | Commit after each successful change |

## Verification Checklist

After each refactoring step:
- [ ] All tests still pass (behavior unchanged)
- [ ] Code is more readable (shorter, clearer names)
- [ ] No new coupling introduced
- [ ] Duplication reduced
- [ ] Commit message clearly states the structural change ("Extract calculateTax method")
- [ ] Performance unchanged (benchmark critical paths if needed)
