## What and why

<!-- One or two sentences: what changes, and the problem it solves. Link the issue: Closes #123 -->

## How it was tested

<!-- Commands you ran, and for UI changes a screenshot or short clip. -->

## Checklist

- [ ] `npm run check` passes with zero analyzer issues (API flows or DB changes: also `npm run test:e2e -w @tamiltaxi/api`)
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org), e.g. `fix(api): …`
- [ ] Docs updated in the same PR: [docs/tech-docs/using.tech.md](https://github.com/sivakrishnacode/tamiltaxi/blob/main/docs/tech-docs/using.tech.md) for stack, env vars, endpoints or infra; README for setup
- [ ] No secrets, keys, `.env` files or personal data in the diff
- [ ] No new paid API calls, or the cost is explained above
