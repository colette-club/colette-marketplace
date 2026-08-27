# Colette Code Conventions — Reference

Five full worked examples, one per rule that doesn't fit in a snippet. `SKILL.md` shows each rule in the smallest form that makes the point; here the same rules run long enough to show the whole shape — every orphaned line, every layer of a pipeline, every sibling test — because that's what the mistake actually looks like in a real diff. Reuse these as a shape to check your own diff against, not as code to copy in.

## An edit that is not finished

Demonstrates **#13 — change hygiene**. One removal upstream — express checkout was dropped from the order form — and four things it should have taken with it: a helper that's collapsed to a single dead branch, a `case` arm that can never be reached, a constant nothing reads anymore, and a doc comment describing a surcharge the code no longer charges.

```ruby
# ❌ BAD — express checkout was removed from the order form, but the
# surcharge constant, the branch that priced it, the case arm that
# estimated its delivery time, and the comment describing it are all
# still here
class ShipmentPricer
  EXPRESS_SURCHARGE_CENTS = 800

  def initialize(shipment)
    @shipment = shipment
  end

  # Adds the express surcharge on top of the base rate when the customer
  # pays for faster delivery.
  def total_cents
    base_rate_cents(@shipment.weight_kg) + express_surcharge(@shipment.method)
  end

  def estimated_days(method)
    case method
    when :standard then 5
    when :express then 2
    else raise ArgumentError, "unknown shipping method: #{method}"
    end
  end

  private

  def base_rate_cents(weight_kg)
    (weight_kg * 120).round
  end

  def express_surcharge(method)
    method == :express ? EXPRESS_SURCHARGE_CENTS : 0
  end
end
```

```ruby
# ✅ GOOD — the constant, the branch that computed the surcharge, the dead
# case arm, and the comment that no longer matched the code are gone with
# the feature; only what still runs remains
class ShipmentPricer
  def initialize(shipment)
    @shipment = shipment
  end

  def total_cents
    base_rate_cents(@shipment.weight_kg)
  end

  def estimated_days
    5
  end

  private

  def base_rate_cents(weight_kg)
    (weight_kg * 120).round
  end
end
```

`method` could only ever be `:standard` once express was removed, which is exactly what made `express_surcharge` collapse to always returning `0` and the `:express` arm in `estimated_days` unreachable — a branch that can never be taken is exactly as dead as one that was deleted. `estimated_days` loses its argument too, once there is only one shipping method left for it to describe.

## A test you can read detached from its file

Demonstrates **#15 — self-contained tests**. Three sibling tests, each hidden behind its own `conftest.py` fixture that builds the exact subscription under assertion. The only thing that changes between them is the day the fixture cancels on — but that day, and therefore the reason for the expected refund, is invisible from the test body.

```python
# ❌ BAD — conftest.py
@pytest.fixture
def subscription_cancelled_at_day_10():
    subscription = Subscription(plan_price_cents=3_000, cycle_days=30)
    subscription.start(on_day=0)
    subscription.cancel(on_day=10)
    return subscription


@pytest.fixture
def subscription_cancelled_at_day_25():
    subscription = Subscription(plan_price_cents=3_000, cycle_days=30)
    subscription.start(on_day=0)
    subscription.cancel(on_day=25)
    return subscription


@pytest.fixture
def subscription_cancelled_on_renewal_day():
    subscription = Subscription(plan_price_cents=3_000, cycle_days=30)
    subscription.start(on_day=0)
    subscription.cancel(on_day=30)
    return subscription


# test_subscription.py — three tests, three fixtures, no visible reason
# why 2_000, 500, and 0 are the right numbers
def test_refund_early_cancellation(subscription_cancelled_at_day_10):
    assert subscription_cancelled_at_day_10.refund_cents == 2_000


def test_refund_late_cancellation(subscription_cancelled_at_day_25):
    assert subscription_cancelled_at_day_25.refund_cents == 500


def test_refund_on_renewal_day(subscription_cancelled_on_renewal_day):
    assert subscription_cancelled_on_renewal_day.refund_cents == 0
```

```python
# ✅ GOOD — each test builds and cancels its own subscription; the day it
# cancels on sits right next to the refund it produces, so the three
# siblings read as one shape with one number changing at a time
def test_refund_early_cancellation():
    subscription = Subscription(plan_price_cents=3_000, cycle_days=30)
    subscription.start(on_day=0)

    subscription.cancel(on_day=10)

    # 20 of 30 days unused, at 100 cents/day
    assert subscription.refund_cents == 2_000


def test_refund_late_cancellation():
    subscription = Subscription(plan_price_cents=3_000, cycle_days=30)
    subscription.start(on_day=0)

    subscription.cancel(on_day=25)

    # 5 of 30 days unused, at 100 cents/day
    assert subscription.refund_cents == 500


def test_refund_on_renewal_day():
    subscription = Subscription(plan_price_cents=3_000, cycle_days=30)
    subscription.start(on_day=0)

    subscription.cancel(on_day=30)

    assert subscription.refund_cents == 0
```

Three fixtures collapse into one shape repeated three times, and a reader can quote any single test in a PR comment and still see why its number is correct. The duplication of `Subscription(plan_price_cents=3_000, cycle_days=30)` across all three is the price paid for that — and it's cheap next to a fixture a reader has to leave the file to understand.

## Three boundary leaks and their fixes

Demonstrates **#12 — application boundaries**. The same rule breaks three different ways: a query that reaches into a table it doesn't own, a domain function that knows who's calling it, and a client that quietly re-derives a rule the other side already owns.

### Leak 1 — reading another service's table directly

```sql
-- ❌ BAD — the reviews service reaches directly into the catalog
-- service's schema to label a review with the product's current name; a
-- rename in catalog.products breaks this join with no warning to anyone
-- who works on reviews
SELECT r.id, r.rating, r.body, p.name AS product_name
FROM reviews.reviews r
JOIN catalog.products p ON p.id = r.product_id;

-- ✅ GOOD — reviews keeps only the id it owns; the name is asked for
-- through catalog's published API at read time, not joined out of a
-- table it doesn't own:
--   catalog_client.get_product(r.product_id) -> { name }
SELECT r.id, r.rating, r.body, r.product_id
FROM reviews.reviews r;
```

### Leak 2 — branching on the calling client

```typescript
// ❌ BAD — the domain function knows which app is calling it and shapes
// its answer accordingly; a third client arrives and either gets the
// mobile-sized response by accident or forces a new branch here
function buildOrderSummary(order: Order, clientType: "mobile" | "web"): OrderSummary {
  if (clientType === "mobile") {
    return { total: order.totalCents, itemCount: order.items.length };
  }
  return {
    total: order.totalCents,
    itemCount: order.items.length,
    lineItems: order.items.map((item) => ({ name: item.name, price: item.priceCents })),
  };
}

// ✅ GOOD — the domain returns everything it knows; trimming the
// response for a given surface is the web layer's job, not the domain's
function buildOrderSummary(order: Order): OrderSummary {
  return {
    total: order.totalCents,
    itemCount: order.items.length,
    lineItems: order.items.map((item) => ({ name: item.name, price: item.priceCents })),
  };
}

// the mobile endpoint picks the fields it renders, in the web layer:
function toMobileResponse(summary: OrderSummary) {
  return { total: summary.total, itemCount: summary.itemCount };
}
```

### Leak 3 — re-implementing the other side's rule

```typescript
// ❌ BAD — checkout re-derives whether a promo code is still valid
// instead of asking promotions for the answer; the two copies of "valid"
// will drift the day promotions changes its expiry rule
function applyPromoCode(cart: Cart, promo: PromoCode): Cart {
  const isStillValid = promo.expiresAt > new Date() && promo.usesRemaining > 0;
  if (!isStillValid) return cart;
  return { ...cart, discountCents: promo.discountCents };
}

// ✅ GOOD — promotions owns the rule and answers the question directly;
// checkout only acts on the answer
async function applyPromoCode(cart: Cart, promoCode: string): Promise<Cart> {
  const promo = await promotionsClient.checkValidity(promoCode);
  if (!promo.valid) return cart;
  return { ...cart, discountCents: promo.discountCents };
}
```

All three fixes share one move: replace a direct read, an audience check, or a re-derived rule with a call across the published boundary, and let the owning side answer.

## One error pipeline, end to end

Demonstrates **#8, #9, #10** together, across the three layers a real request actually crosses: a typed error defined and raised where the rule lives, an application layer that calls through to it without adding a catch of its own, and an HTTP boundary that is the one and only place the error becomes a status code.

### Layer 1 — the source

```typescript
// domain/wallet.ts
// A typed error, not a string or a generic Error, defined once and
// thrown when the domain rule is violated (#9).
export class InsufficientBalanceError extends Error {
  constructor(
    readonly walletId: string,
    readonly requestedCents: number,
    readonly availableCents: number,
  ) {
    super(`wallet ${walletId} has ${availableCents} cents, requested ${requestedCents}`);
    this.name = "InsufficientBalanceError";
  }
}

export function withdraw(wallet: Wallet, amountCents: number): Wallet {
  if (amountCents > wallet.balanceCents) {
    throw new InsufficientBalanceError(wallet.id, amountCents, wallet.balanceCents);
  }
  return { ...wallet, balanceCents: wallet.balanceCents - amountCents };
}
```

### Layer 2 — the middle

```typescript
// application/withdraw-funds.ts
// Calls the domain, persists the result, and adds nothing of its own to
// the error path — no catch, no re-throw, no translation. What the
// domain threw is exactly what reaches the caller (#8: nothing here
// swallows or repackages it).
export async function withdrawFunds(walletId: string, amountCents: number): Promise<Wallet> {
  const wallet = await walletRepository.findById(walletId);
  const updated = withdraw(wallet, amountCents);
  await walletRepository.save(updated);
  return updated;
}
```

### Layer 3 — the boundary

```typescript
// http/wallet-controller.ts
// The ONLY place in the app that knows InsufficientBalanceError maps to
// 422 (#10: mapped once, here, and nowhere else).
export async function handleWithdraw(req: Request, res: Response): Promise<void> {
  try {
    const wallet = await withdrawFunds(req.params.walletId, req.body.amountCents);
    res.status(200).json(wallet);
  } catch (err) {
    if (err instanceof InsufficientBalanceError) {
      res.status(422).json({ error: "insufficient_balance", walletId: err.walletId });
      return;
    }
    throw err; // not this pipeline's error — the app-wide handler takes it
  }
}
```

Nothing between the `throw` in layer 1 and the `catch` in layer 3 touches the error. If a second `catch (InsufficientBalanceError)` ever shows up in a service or a resolver somewhere in the middle, that's rule #10 breaking: two places now decide what the error means, and they will eventually disagree.

## A contract mirrored through the layers

Demonstrates **#11 — mirror the contract exactly**. The wire type says `email` is required and `middleName` is optional. Watch what happens to that distinction by the time it reaches the view model.

```typescript
// ❌ BAD — the mapping layer widens both fields: `email` becomes
// optional "just in case", and `middleName` gets defaulted to "" instead
// of staying absent. Two layers down, the view model can no longer tell
// "no middle name" from "middle name not loaded yet", and every reader
// of `email` now has to handle a case the wire format never allowed.
interface CustomerResponse {
  id: string;
  email: string;
  middleName?: string;
}

interface Customer {
  id: string;
  email?: string; // widened: was required on the wire
  middleName: string; // widened: was optional on the wire, defaulted here
}

function toCustomer(response: CustomerResponse): Customer {
  return {
    id: response.id,
    email: response.email,
    middleName: response.middleName ?? "",
  };
}

interface CustomerViewModel {
  id: string;
  email?: string;
  middleName: string;
}

function toViewModel(customer: Customer): CustomerViewModel {
  return { id: customer.id, email: customer.email, middleName: customer.middleName };
}
```

```typescript
// ✅ GOOD — the same optionality holds at every layer: `email` is
// required everywhere, `middleName` stays optional everywhere, and
// "absent" is never confused with "empty string"
interface CustomerResponse {
  id: string;
  email: string;
  middleName?: string;
}

interface Customer {
  id: string;
  email: string;
  middleName?: string;
}

function toCustomer(response: CustomerResponse): Customer {
  return { id: response.id, email: response.email, middleName: response.middleName };
}

interface CustomerViewModel {
  id: string;
  email: string;
  middleName?: string;
}

function toViewModel(customer: Customer): CustomerViewModel {
  return { id: customer.id, email: customer.email, middleName: customer.middleName };
}
```

Three interfaces, three mapping functions, one contract: `id` and `email` are never optional and `middleName` never gets a placeholder default. A component reading `customer.middleName` still has to handle "absent" — but it's the one real case the API can produce, not one invented by a mapping layer along the way.
