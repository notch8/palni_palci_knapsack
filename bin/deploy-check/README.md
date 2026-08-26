# Deploy regression check

A knapsack deploy can change tenant behaviour without anything appearing in the
deploy log, and fifteen tenants is more than anyone checks by hand. `snapshot.rb`
records the state that matters per tenant; `compare.rb` diffs a before and after
capture and exits non-zero if anything in the must-not-change set moved.

**Capture the baseline before the deploy.** It cannot be reconstructed afterwards.

| Environment | Context | Namespace |
|---|---|---|
| production | `r2-besties` | `palni-palci-knapsack-production` |
| friends | `r2-friends` | `palni-palci-knapsack-friends` |

```bash
CTX=r2-besties; NS=palni-palci-knapsack-production
POD() { kubectl --context $CTX -n $NS get pods --no-headers | awk '/-hyrax-[0-9a-f]/{print $1; exit}'; }

# Before the deploy
kubectl --context $CTX -n $NS exec -i $(POD) -- bundle exec rails runner - \
  < bin/deploy-check/snapshot.rb | sed -n '/^{/,$p' > before.json

# After (the deploy replaces the pod, so POD is re-resolved)
kubectl --context $CTX -n $NS exec -i $(POD) -- bundle exec rails runner - \
  < bin/deploy-check/snapshot.rb | sed -n '/^{/,$p' > after.json

bin/deploy-check/compare.rb before.json after.json
```

The `sed` strips Rails boot warnings that precede the JSON — without it the file
will not parse.

`snapshot.rb` is strictly read-only.

## Fails the check

- `available_works` — a tenant's depositors gaining or losing work types
- `themes`, `schema_classes`
- an existing feature flag whose **value** changed
- a tenant disappearing, newly erroring, or a sample work losing its thumbnail
- global registered work types, derivative labels, viewer and manifest config

Reported but not failed: counts, vocabulary term counts, schema version, Hyrax and
Puma versions, feature flags that **appeared or vanished** (an upgrade adds flags;
that is not a regression), and any key the previous version could not report.

Identical findings across many tenants collapse to one line with a count, so a
fleet-wide change reads as one finding rather than fifteen.

A non-zero exit means look closer, not necessarily that something broke — an
intended change such as flipping a config flag will also fail, which is correct.

## Sequence check

`sequence_check.rb` reports any tenant whose `id` sequence has fallen behind
`max(id)`. When that happens the next insert reuses an existing id and Postgres
raises `PG::UniqueViolation` on the primary key — which surfaces as a failed
metadata profile import or vocabulary create, with nothing obviously wrong in the
logs. It reads `last_value` rather than calling `nextval`, so it consumes nothing.

```bash
kubectl --context $CTX -n $NS exec -i $(POD) -- bundle exec rails runner - \
  < bin/deploy-check/sequence_check.rb
```

To repair a tenant that is behind:

```ruby
%w[hyrax_flexible_schemas qa_local_authorities qa_local_authority_entries].each do |t|
  ActiveRecord::Base.connection.execute(
    "SELECT setval(pg_get_serial_sequence('#{t}','id'), (SELECT COALESCE(MAX(id),1) FROM #{t}))"
  )
end
```

## Not covered — check these by hand

- **Static assets.** Fetch the homepage, extract the fingerprinted
  `/assets/application-*.css`, and confirm it returns 200. Where the nginx image
  bakes assets at build time, a bad build is an unstyled site, not an error.
- **Migration duration**, against whatever `--timeout` `bin/helm_deploy` uses.
- **Behaviour under load.**

## Why `available_works` is the one to watch

`Site#available_works` is a persisted column seeded only when the Site row is
created (`Site.instance` uses `first_or_create`). Nothing recomputes it at boot or
during migration, so a deploy alone cannot change it — which is exactly why a change
there means something wrote to it, and is worth failing on.

## Baselines

Keep only the capture for the deploy currently being gated. A baseline's value is
comparative, so once the post-deploy diff is clean the file is dead weight — prune
it rather than accumulating one per deploy.
