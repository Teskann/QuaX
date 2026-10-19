// node --test .github/triage/apply.test.js
const test = require('node:test')
const assert = require('node:assert/strict')
const apply = require('./apply.js')

const LABELS = ['bug', 'needs info', 'Feature request']

const commentWith = (json) => `Looks like a duplicate of #12.\n\n<!-- quax-triage ${json} -->`

function fakeGithub(labels = LABELS) {
  const calls = []
  const record = (name) => async (args) => {
    calls.push({ name, args })
    if (name === 'removeLabel' && !labels.includes(args.name)) throw { status: 404 }
  }
  const rest = {
    issues: Object.fromEntries(
      ['createLabel', 'addLabels', 'removeLabel', 'update'].map((n) => [
        n,
        record(n),
      ]),
    ),
  }
  const paginate = async () => labels.map((name) => ({ name }))
  return { github: { rest, paginate }, calls }
}

const run = (github, body) =>
  apply({
    github,
    context: {
      repo: { owner: 'Teskann', repo: 'QuaX' },
      payload: { issue: { number: 42 }, comment: { body } },
    },
    core: { info: () => {} },
  })

const names = (calls) => calls.map((call) => call.name)

test('Should add existing labels and close the issue it is posted on', async () => {
  const { github, calls } = fakeGithub()
  await run(github, commentWith('{"add_labels": ["bug", "Feature request"], "close": "completed"}'))
  assert.deepEqual(
    names(calls),
    ['addLabels', 'update'],
    'Only the requested calls should be made',
  )
  assert.equal(calls[0].args.issue_number, 42, 'Labels should go to the commented issue')
  assert.deepEqual(calls[0].args.labels, ['bug', 'Feature request'], 'Every label should be added')
  assert.equal(calls[1].args.state_reason, 'completed', 'The close reason should be passed on')
})

test('Should create a declared new label before adding it', async () => {
  const { github, calls } = fakeGithub()
  const json = `{"new_labels": [{"name": "login", "description": "Sign in", "color": "1d76db"}],
                 "add_labels": ["login"]}`
  await run(github, commentWith(json))
  assert.deepEqual(
    names(calls),
    ['createLabel', 'addLabels'],
    'The label should exist first',
  )
  assert.equal(calls[0].args.color, '1d76db', 'The label should keep its color')
})

test('Should not recreate a new label that already exists', async () => {
  const { github, calls } = fakeGithub()
  const json = `{"new_labels": [{"name": "bug", "description": "Bug", "color": "d73a4a"}],
                 "add_labels": ["bug"]}`
  await run(github, commentWith(json))
  assert.deepEqual(
    names(calls),
    ['addLabels'],
    'An existing label should be left as is',
  )
})

test('Should ignore a missing needs info label', async () => {
  const { github, calls } = fakeGithub(['bug'])
  await run(github, commentWith('{"remove_needs_info": true}'))
  assert.deepEqual(
    names(calls),
    ['removeLabel'],
    'A 404 on removal should not fail the run',
  )
})

const rejected = [
  ['an unknown label', '{"add_labels": ["wontfix"]}', /Unknown labels: wontfix/],
  ['an unknown field', '{"add_labels": ["bug"], "issue": 7}', /\$\.issue is not allowed/],
  ['an inherited field name', '{"constructor": 1}', /\$\.constructor is not allowed/],
  ['an invalid close reason', '{"close": "spam"}', /must be one of/],
  ['removing another label', '{"remove_needs_info": "bug"}', /must be true/],
  ['an empty block', '{}', /properties/],
  ['a label that closes the comment early', '{"add_labels": ["bug -->"]}', /JSON/],
  ['a shell payload', '{"add_labels": ["$(curl x)"]}', /must match/],
  ['too many labels', '{"add_labels": ["a","b","c","d","e","f"]}', /allows 5 items/],
  ['a malformed JSON', '{"add_labels": [', /JSON/],
  ['an array', '[]', /must be a object/],
]

for (const [what, json, error] of rejected) {
  test(`Should reject ${what} without calling GitHub`, async () => {
    const { github, calls } = fakeGithub()
    await assert.rejects(run(github, commentWith(json)), error, `${what} should be refused`)
    assert.deepEqual(names(calls), [], `Nothing should be applied for ${what}`)
  })
}

test('Should reject two blocks in one comment', async () => {
  const { github, calls } = fakeGithub()
  const body = `${commentWith('{"close": "completed"}')}\n${commentWith('{"close": "not_planned"}')}`
  await assert.rejects(run(github, body), /got 2/, 'Two blocks should be ambiguous')
  assert.deepEqual(names(calls), [], 'Nothing should be applied')
})
