// Applies the triage action quax-bot wrote in its comment. Run by actions/github-script: the comment
// is only ever handled as data, parsed with JSON.parse and sent to the REST API, never to a shell.

const fs = require('fs')
const path = require('path')
const { validate } = require('./validate.js')

const BLOCK = /<!-- quax-triage\s*([\s\S]*?)\s*-->/g
const NEEDS_INFO = 'needs info'

const schema = JSON.parse(fs.readFileSync(path.join(__dirname, 'action.schema.json'), 'utf8'))

function parseAction(body) {
  const blocks = [...body.matchAll(BLOCK)]
  if (blocks.length !== 1) throw new Error(`Expected one quax-triage block, got ${blocks.length}`)
  const action = JSON.parse(blocks[0][1])
  const errors = validate(schema, action)
  if (errors.length > 0) throw new Error(`Invalid quax-triage block: ${errors.join('; ')}`)
  return action
}

async function repoLabels(github, repo) {
  const labels = await github.paginate(github.rest.issues.listLabelsForRepo, {
    ...repo,
    per_page: 100,
  })
  return new Set(labels.map((label) => label.name))
}

// Adding an unknown label would silently create it: only the ones declared in new_labels may be.
function checkLabelsExist(action, existing) {
  const declared = new Set((action.new_labels ?? []).map((label) => label.name))
  const unknown = (action.add_labels ?? []).filter((n) => !existing.has(n) && !declared.has(n))
  if (unknown.length > 0) throw new Error(`Unknown labels: ${unknown.join(', ')}`)
}

async function removeNeedsInfo(github, issue) {
  try {
    await github.rest.issues.removeLabel({ ...issue, name: NEEDS_INFO })
  } catch (error) {
    if (error.status !== 404) throw error
  }
}

async function applyAction(github, repo, issue, action, existing) {
  const missing = (action.new_labels ?? []).filter((label) => !existing.has(label.name))
  for (const label of missing) await github.rest.issues.createLabel({ ...repo, ...label })
  if (action.add_labels) await github.rest.issues.addLabels({ ...issue, labels: action.add_labels })
  if (action.remove_needs_info) await removeNeedsInfo(github, issue)
  if (action.close) {
    await github.rest.issues.update({ ...issue, state: 'closed', state_reason: action.close })
  }
}

module.exports = async ({ github, context, core }) => {
  const repo = context.repo
  const issue = { ...repo, issue_number: context.payload.issue.number }
  const action = parseAction(context.payload.comment.body)
  const existing = await repoLabels(github, repo)
  checkLabelsExist(action, existing)
  await applyAction(github, repo, issue, action, existing)
  core.info(`Applied to #${issue.issue_number}: ${JSON.stringify(action)}`)
}
